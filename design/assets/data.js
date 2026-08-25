const Mock = (() => {
  const now = () => Date.now();
  const H = 3600e3, D = 86400e3;

  const containers = [
    { id: 'web-server', image: 'nginx:1.27-alpine', status: 'running', cpus: 2, memLimit: 1073741824,
      cpuPct: 1.2, memBytes: 46137344, rxRate: 12400, txRate: 48200, ip: '192.168.64.3', network: 'default',
      ports: [{ host: '8080', ct: '80', proto: 'tcp' }], created: now() - 5 * H, startedAt: now() - 5 * H,
      cmd: 'nginx -g "daemon off;"', entrypoint: '', workdir: '/usr/share/nginx/html', user: 'root',
      env: { NGINX_ENVSUBST_OUTPUT_DIR: '/etc/nginx/conf.d' }, mounts: [{ src: 'site-content', dst: '/usr/share/nginx/html' }],
      init: false, rosetta: false, readOnly: true, autoRemove: false, tty: false },
    { id: 'redis-cache', image: 'redis:7.4-alpine', status: 'running', cpus: 2, memLimit: 536870912,
      cpuPct: 0.6, memBytes: 18874368, rxRate: 8200, txRate: 9100, ip: '192.168.64.4', network: 'default',
      ports: [], created: now() - 3 * D, startedAt: now() - 26 * H,
      cmd: 'redis-server --appendonly yes', entrypoint: '', workdir: '/data', user: 'root',
      env: {}, mounts: [{ src: 'redis-data', dst: '/data' }],
      init: false, rosetta: false, readOnly: false, autoRemove: false, tty: false },
    { id: 'postgres-db', image: 'postgres:17.2', status: 'running', cpus: 4, memLimit: 2147483648,
      cpuPct: 3.4, memBytes: 198180864, rxRate: 45200, txRate: 61800, ip: '192.168.64.5', network: 'default',
      ports: [{ host: '5432', ct: '5432', proto: 'tcp' }], created: now() - 12 * D, startedAt: now() - 26 * H,
      cmd: 'postgres', entrypoint: 'docker-entrypoint.sh', workdir: '/', user: 'postgres',
      env: { POSTGRES_DB: 'app', POSTGRES_PASSWORD: '••••••••' }, mounts: [{ src: 'pg-data', dst: '/var/lib/postgresql/data' }],
      init: true, rosetta: false, readOnly: false, autoRemove: false, tty: false },
    { id: 'api-server', image: 'my-app:v1.4.0', status: 'running', cpus: 2, memLimit: 1073741824,
      cpuPct: 8.9, memBytes: 142606336, rxRate: 210000, txRate: 187000, ip: '192.168.65.2', network: 'dev-net',
      ports: [{ host: '3000', ct: '3000', proto: 'tcp' }], created: now() - 2 * H, startedAt: now() - 2 * H,
      cmd: 'node server.js', entrypoint: '', workdir: '/app', user: 'node',
      env: { NODE_ENV: 'production', PORT: '3000' }, mounts: [],
      init: true, rosetta: false, readOnly: true, autoRemove: false, tty: false },
    { id: 'build-runner', image: 'ubuntu:24.04', status: 'stopped', exitCode: 0, cpus: 4, memLimit: 4294967296,
      cpuPct: 0, memBytes: 0, rxRate: 0, txRate: 0, ip: '—', network: 'default',
      ports: [], created: now() - 8 * H, finishedAt: now() - 6 * H,
      cmd: '/bin/bash', entrypoint: '', workdir: '/workspace', user: 'root',
      env: {}, mounts: [], init: false, rosetta: false, readOnly: false, autoRemove: false, tty: true },
    { id: 'net-probe', image: 'alpine/curl:latest', status: 'exited', exitCode: 1, cpus: 1, memLimit: 536870912,
      cpuPct: 0, memBytes: 0, rxRate: 0, txRate: 0, ip: '—', network: 'default',
      ports: [], created: now() - 40 * 60000, finishedAt: now() - 39 * 60000,
      cmd: 'curl -sf http://web-server.test:80', entrypoint: '', workdir: '/', user: 'root',
      env: {}, mounts: [], init: false, rosetta: false, readOnly: false, autoRemove: false, tty: false }
  ];

  const L = (cmd, size) => ({ cmd, size });
  const images = [
    { ref: 'nginx:1.27-alpine', id: 'a3f4b2c91d07', size: 54525952, os: 'linux', arch: 'arm64', created: now() - 21 * D,
      digest: 'sha256:1f42c5a0…8e21', usedBy: ['web-server'],
      layers: [L('ADD file:e4d9… in / ', 5242880), L('CMD ["nginx" "-g" "daemon off;"]', 1024), L('EXPOSE 80', 1024), L('COPY nginx.conf /etc/nginx/', 4096)] },
    { ref: 'redis:7.4-alpine', id: 'b8d2e7f04a19', size: 62914560, os: 'linux', arch: 'arm64', created: now() - 30 * D,
      digest: 'sha256:9c11de77…02aa', usedBy: ['redis-cache'], layers: [L('ADD file:c0b1… in / ', 5242880), L('ENTRYPOINT ["docker-entrypoint.sh"]', 1024), L('CMD ["redis-server"]', 1024)] },
    { ref: 'postgres:17.2', id: 'c91f3a28be44', size: 450971566, os: 'linux', arch: 'arm64', created: now() - 15 * D,
      digest: 'sha256:77b0fe31…cc41', usedBy: ['postgres-db'], layers: [L('ADD file:923f… in / ', 12582912), L('RUN apt-get install -y postgresql', 387973120), L('VOLUME /var/lib/postgresql/data', 1024), L('ENTRYPOINT ["docker-entrypoint.sh"]', 2048)] },
    { ref: 'my-app:v1.4.0', id: 'd02aa917cf63', size: 186227097, os: 'linux', arch: 'arm64', created: now() - 2 * H,
      digest: 'sha256:ab4410d9…71f3', usedBy: ['api-server'],
      layers: [L('FROM node:20-alpine', 133169152), L('WORKDIR /app', 1024), L('COPY package*.json ./', 12288), L('RUN npm ci --omit=dev', 41943040), L('COPY . .', 11141120), L('CMD ["node", "server.js"]', 2048)] },
    { ref: 'ubuntu:24.04', id: 'e55c81bb90f2', size: 78643200, os: 'linux', arch: 'arm64', created: now() - 45 * D,
      digest: 'sha256:33a61beb…9dd0', usedBy: [], layers: [L('ADD file:f9df… in / ', 78643200), L('CMD ["/bin/bash"]', 1024)] },
    { ref: 'alpine:3.22', id: 'f7712da30e58', size: 15728640, os: 'linux', arch: 'arm64', created: now() - 60 * D,
      digest: 'sha256:6cd1a2b9…4e88', usedBy: [], layers: [L('ADD file:a7c9… in / ', 15728640), L('CMD ["/bin/sh"]', 1024)] },
    { ref: '<none>:d0a3f9c2e1', id: 'd0a3f9c2e1b7', size: 8388608, os: 'linux', arch: 'arm64', created: now() - 4 * H,
      digest: 'sha256:0aa4d17c…f19b', usedBy: [], dangling: true, layers: [L('ADD file:tmp in / ', 8388608)] }
  ];

  const volumes = [
    { name: 'pg-data', driver: 'local', size: 10737418240, journal: null, usedBy: ['postgres-db'], created: now() - 12 * D },
    { name: 'redis-data', driver: 'local', size: 1073741824, journal: 'ordered', usedBy: ['redis-cache'], created: now() - 3 * D },
    { name: 'site-content', driver: 'local', size: null, journal: null, usedBy: ['web-server'], created: now() - 5 * H },
    { name: 'build-cache-01', driver: 'local', size: 2147483648, journal: null, usedBy: [], created: now() - 9 * D }
  ];

  const networks = [
    { name: 'default', subnet4: '192.168.64.0/24', subnet6: null, internal: false, system: true,
      attached: ['web-server', 'redis-cache', 'postgres-db'] },
    { name: 'dev-net', subnet4: '192.168.65.0/24', subnet6: null, internal: false, system: false,
      attached: ['api-server'] },
    { name: 'lab-isolated', subnet4: '192.168.100.0/24', subnet6: 'fd00:abcd::/64', internal: true, system: false,
      attached: [] }
  ];

  const machines = [
    { name: 'dev-machine', image: 'alpine:3.22', state: 'running', cpus: 4, mem: 8589934592,
      homeMount: 'rw', virtualization: false, isDefault: true, created: now() - 20 * D },
    { name: 'ci-runner', image: 'ubuntu:24.04', state: 'stopped', cpus: 2, mem: 4294967296,
      homeMount: 'ro', virtualization: true, isDefault: false, created: now() - 6 * D }
  ];

  const k8s = [
    { name: 'k8s-dev', nodeImage: 'docker.io/kindest/node:v1.35.5', state: 'running', cpus: 4, memBytes: 8589934592,
      autoRemove: false, created: now() - 3 * D },
    { name: 'ci-cluster', nodeImage: 'docker.io/kindest/node:v1.34.0', state: 'stopped', cpus: 2, memBytes: 4294967296,
      autoRemove: true, created: now() - 9 * D }
  ];

  const k8sLoaded = { 'k8s-dev': ['my-app:v1.4.0', 'alpine:3.22'], 'ci-cluster': [] };

  const registries = [
    { server: 'docker.io', user: 'amlei', scheme: 'auto' },
    { server: 'ghcr.io', user: 'amlei-dev', scheme: 'https' }
  ];

  const dnsDomains = ['test'];

  const system = {
    servicesRunning: true, startedAt: now() - 26 * H,
    versionCli: '1.2.3', buildType: 'release', commitCli: 'abcdef1',
    versionApi: 'container-apiserver version 1.2.3 (build: release, commit: 1234abc)',
    kernel: { path: 'opt/kata/share/kata-containers/vmlinux-6.18.35-197-debug', arch: 'arm64', digest: 'sha256:8736c054…9b6e4b5' },
    defaultRegistry: 'docker.io'
  };

  const df = {
    images: { count: 6, activeCount: 4, size: 1019828224, activeSize: 872415232 },
    containers: { count: 6, activeCount: 4, size: 1284320256, reclaimable: 402653184 },
    volumes: { count: 4, activeCount: 3, size: 13958643712, reclaimable: 2147483648 },
    cache: { size: 314572800, reclaimable: 314572800 }
  };

  const props = {
    build: { cpus: 2, memory: '"2048mb"', rosetta: true, image: '"ghcr.io/apple/container-builder-shim/builder:0.13.1"' },
    container: { cpus: 4, memory: '"1gb"' },
    dns: { domain: '"test"' },
    kernel: { binaryPath: '"opt/kata/share/kata-containers/vmlinux-6.18.35-197-debug"',
      url: '"https://github.com/kata-containers/kata-containers/releases/download/3.32.0/kata-static-3.32.0-arm64.tar.zst"',
      digest: '"sha256:8736c054d9223974735394f822000823baef509e1c33405ec798240fa9b6e4b5"' },
    network: {},
    registry: { domain: '"docker.io"' },
    vminit: { image: '"ghcr.io/apple/containerization/vminit:0.34.0"' }
  };

  const sysLogTemplates = [
    ['apiserver', 'request completed method=GET path=/services/list status=200 duration=2.4ms'],
    ['apiserver', 'container runtime helper launched id=web-server handler=container-runtime-linux'],
    ['core-images', 'content store gc reclaimed={size}B'],
    ['network-vmnet', 'interface up network=default subnet=192.168.64.0/24'],
    ['apiserver', 'health check ok uptime={uptime}s'],
    ['runtime-linux', 'exec completed container=redis-cache exit=0'],
    ['core-images', 'image resolved ref=alpine:3.22 platform=linux/arm64'],
    ['apiserver', 'watch event kind=CONTAINER action=STARTED id=api-server']
  ];

  const logTemplates = {
    'nginx:1.27-alpine': [
      '172.16.64.1 - - [date] "GET / HTTP/1.1" 200 615 "-" "curl/8.7.1"',
      '172.16.64.1 - - [date] "GET /assets/app.css HTTP/1.1" 200 1204 "-" "Mozilla/5.0"',
      '192.168.64.5 - - [date] "GET /healthz HTTP/1.1" 200 2 "-" "kube-probe"',
      '172.16.64.1 - - [date] "POST /api/login HTTP/1.1" 401 39 "-" "python-requests/2.32"'
    ],
    'redis:7.4-alpine': [
      '* Background saving terminated with success',
      '* DB saved on disk',
      '* 100 changes in 60 seconds. Saving…',
      '* Ready to accept connections tcp'
    ],
    'postgres:17.2': [
      'LOG:  checkpoint starting: time',
      'LOG:  checkpoint complete: wrote 842 buffers (0.4%); 0 WAL file(s) added',
      'LOG:  database system is ready to accept connections',
      'ERROR:  duplicate key value violates unique constraint "users_pkey"'
    ],
    'my-app:v1.4.0': [
      '[api] request completed GET /v1/health 200 3ms',
      '[worker] job #4821 finished in 128ms',
      '[api] POST /v1/orders 201 41ms',
      '[cache] hit rate 94.2% window=60s'
    ]
  };
  const bootLog = [
    'Linux version 6.18.35 (builder@container) #1 SMP PREEMPT',
    'Command line: console=hvc0 quiet',
    'Memory: 1048576K available',
    'virtio_blk virtio2: [vda] detected',
    'EXT4-fs (vda): mounted filesystem without journal',
    'vminitd: starting init services',
    'vminitd: mounted /etc/hosts /etc/resolv.conf',
    'init: container runtime ready, handing over to runtime-linux'
  ];

  return { containers, images, volumes, networks, machines, k8s, k8sLoaded, registries, dnsDomains, system, df, props, logTemplates, bootLog, sysLogTemplates };
})();
