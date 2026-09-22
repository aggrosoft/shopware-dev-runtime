package main

import (
	"context"
	"fmt"
	"net"
	"os"
	"strings"

	"github.com/moby/moby/api/types/network"
	"github.com/moby/moby/client"
	"github.com/tg123/sshpiper/libplugin"
	"github.com/tg123/sshpiper/libplugin/skel"
	"github.com/urfave/cli/v2"
)

const (
	labelUsername          = "sshpiper.username"
	labelContainerUsername = "sshpiper.container_username"
	labelPort              = "sshpiper.port"
	labelNetwork           = "sshpiper.network"
	labelDevKeys           = "sshpiper.dev_keys"

	defaultAuthorizedKeys = "/etc/sshpiper/dev_authorized_keys"
	defaultPrivateKey     = "/etc/sshpiper/dev_upstream_key"
)

type pipe struct {
	ClientUsername    string
	ContainerUsername string
	Host              string
	DevKeys           bool
}

type dockerRouter struct {
	dockerCli          *client.Client
	authorizedKeysPath string
	privateKeyPath     string
}

type pipeWrapper struct {
	router *dockerRouter
	pipe   *pipe
}

type fromBase struct{ pipeWrapper }
type fromPassword struct{ fromBase }
type fromPublicKey struct{ fromBase }

type toBase struct {
	pipeWrapper
	username string
}
type toPassword struct{ toBase }
type toPrivateKey struct{ toBase }

func main() {
	libplugin.CreateAndRunPluginTemplate(&libplugin.PluginTemplate{
		Name:  "docker-dev",
		Usage: "Docker router with centrally managed development SSH keys",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "authorized-keys",
				Value:   defaultAuthorizedKeys,
				EnvVars: []string{"SSHPIPERD_DOCKER_DEV_AUTHORIZED_KEYS"},
			},
			&cli.StringFlag{
				Name:    "private-key",
				Value:   defaultPrivateKey,
				EnvVars: []string{"SSHPIPERD_DOCKER_DEV_PRIVATE_KEY"},
			},
		},
		CreateConfig: func(c *cli.Context) (*libplugin.SshPiperPluginConfig, error) {
			cli, err := client.New(client.FromEnv)
			if err != nil {
				return nil, err
			}

			router := &dockerRouter{
				dockerCli:          cli,
				authorizedKeysPath: c.String("authorized-keys"),
				privateKeyPath:     c.String("private-key"),
			}

			s := skel.NewSkelPlugin(router.listPipes)
			return s.CreateConfig(), nil
		},
	})
}

func (w *pipeWrapper) From() []skel.SkelPipeFrom {
	base := fromBase{pipeWrapper: *w}

	methods := []skel.SkelPipeFrom{
		&fromPassword{fromBase: base},
	}

	if w.pipe.DevKeys {
		methods = append(methods, &fromPublicKey{fromBase: base})
	}

	return methods
}

func (f *fromPassword) MatchConn(conn libplugin.ConnMetadata) (skel.SkelPipeTo, error) {
	if !f.matches(conn) {
		return nil, nil
	}

	return &toPassword{toBase: f.target(conn)}, nil
}

func (f *fromPublicKey) MatchConn(conn libplugin.ConnMetadata) (skel.SkelPipeTo, error) {
	if !f.pipe.DevKeys || !f.matches(conn) {
		return nil, nil
	}

	return &toPrivateKey{toBase: f.target(conn)}, nil
}

func (f *fromBase) matches(conn libplugin.ConnMetadata) bool {
	return f.pipe.ClientUsername == conn.User()
}

func (f *fromBase) target(conn libplugin.ConnMetadata) toBase {
	username := f.pipe.ContainerUsername
	if username == "" {
		username = conn.User()
	}

	return toBase{
		pipeWrapper: f.pipeWrapper,
		username:    username,
	}
}

func (f *fromPassword) TestPassword(_ libplugin.ConnMetadata, _ []byte) (bool, error) {
	// Password authentication is verified by the target container's sshd.
	return true, nil
}

func (f *fromPublicKey) AuthorizedKeys(_ libplugin.ConnMetadata) ([]byte, error) {
	return os.ReadFile(f.router.authorizedKeysPath)
}

func (f *fromPublicKey) TrustedUserCAKeys(_ libplugin.ConnMetadata) ([]byte, error) {
	return nil, nil
}

func (t *toBase) Host(_ libplugin.ConnMetadata) string {
	return t.pipe.Host
}

func (t *toBase) User(_ libplugin.ConnMetadata) string {
	return t.username
}

func (t *toBase) KnownHosts(_ libplugin.ConnMetadata) ([]byte, error) {
	// Same behavior as the stock docker plugin: container host keys are not pinned.
	return nil, nil
}

func (t *toPassword) OverridePassword(_ libplugin.ConnMetadata) ([]byte, error) {
	// Forward the password supplied by the downstream SSH client.
	return nil, nil
}

func (t *toPrivateKey) PrivateKey(_ libplugin.ConnMetadata) ([]byte, []byte, error) {
	key, err := os.ReadFile(t.router.privateKeyPath)
	if err != nil {
		return nil, nil, err
	}

	return key, nil, nil
}

func (r *dockerRouter) listPipes(_ libplugin.ConnMetadata) ([]skel.SkelPipe, error) {
	res, err := r.dockerCli.ContainerList(context.Background(), client.ContainerListOptions{})
	if err != nil {
		return nil, err
	}

	pipes := make([]skel.SkelPipe, 0, len(res.Items))

	for _, c := range res.Items {
		username := c.Labels[labelUsername]
		if username == "" {
			continue
		}

		host, err := r.containerHost(c.NetworkSettings.Networks, c.Labels[labelNetwork])
		if err != nil {
			continue
		}

		port := c.Labels[labelPort]
		if port == "" {
			port = "22"
		}

		p := &pipe{
			ClientUsername:    username,
			ContainerUsername: c.Labels[labelContainerUsername],
			Host:              net.JoinHostPort(host, port),
			DevKeys:           strings.EqualFold(c.Labels[labelDevKeys], "true"),
		}

		pipes = append(pipes, &pipeWrapper{router: r, pipe: p})
	}

	return pipes, nil
}

func (r *dockerRouter) containerHost(networks map[string]*network.EndpointSettings, requestedNetwork string) (string, error) {
	candidates := make([]*network.EndpointSettings, 0, len(networks))

	for _, nw := range networks {
		if nw != nil && nw.IPAddress.IsValid() {
			candidates = append(candidates, nw)
		}
	}

	if len(candidates) == 0 {
		return "", fmt.Errorf("container has no usable IP address")
	}

	if len(candidates) == 1 {
		return candidates[0].IPAddress.String(), nil
	}

	if requestedNetwork == "" {
		return "", fmt.Errorf("container has multiple networks but %s is empty", labelNetwork)
	}

	target, err := r.dockerCli.NetworkInspect(context.Background(), requestedNetwork, client.NetworkInspectOptions{})
	if err != nil {
		return "", err
	}

	for _, candidate := range candidates {
		if candidate.NetworkID == target.Network.ID {
			return candidate.IPAddress.String(), nil
		}
	}

	return "", fmt.Errorf("container is not attached to requested network %s", requestedNetwork)
}
