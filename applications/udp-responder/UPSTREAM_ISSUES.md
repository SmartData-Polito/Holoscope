# UDP Responder — Upstream Issues

Issues found during Holoscope integration review. To be reported to the
original author for fixing in the upstream `udpspoofer` repository.

---

## Bug 1: UDP packet fields never populated in ClickHouse inserts

**Files:** `cmd/udpspoofer/main.go:349-356`, `internal/netutil/ip.go:46-53`

The `UdpPacket` struct defines `UDPLength` and `UDPChecksum` fields, but the
capture code never assigns them:

- `udppacket.UDPLength` is never set (should be `udp.Length`)
- `udppacket.Checksum = udp.Checksum` writes to the embedded `IpPacket.Checksum`
  field instead of `UdpPacket.UDPChecksum`

**Impact:** ClickHouse receives zero values for UDP length and checksum columns.

**Fix:** Add `udppacket.UDPLength = udp.Length` and change to
`udppacket.UDPChecksum = udp.Checksum`.

---

## Bug 2: TCP checksum assigned to wrong struct field

**Files:** `cmd/udpspoofer/main.go:329`, `internal/netutil/ip.go:40`

Same pattern as Bug 1. `tcppacket.Checksum = tcp.Checksum` writes to the
embedded `IpPacket.Checksum` instead of `TcpPacket.TCPChecksum`.

**Impact:** TCP checksum column in ClickHouse is always zero.

**Fix:** Change to `tcppacket.TCPChecksum = tcp.Checksum`.

---

## Bug 3: Rate limiter state lost on packet source reconnect

**File:** `cmd/udpspoofer/main.go:219-223, 272`

The `udpLimiter` is created inside the outer `for {}` retry loop. When the
`packetSource.Packets()` channel closes (e.g., interface flap), the loop
restarts and creates a fresh limiter — losing all rate-limit state (blocked
IPs, counters, timing windows).

**Impact:** An attacker could bypass rate limits by causing a brief interface
disruption. All accumulated block state is silently discarded.

**Fix:** Move `udpLimiter` creation before the outer loop.

---

## Bug 4: Panic on missing .env file

**File:** `cmd/udpspoofer/main.go:72-75`

`config.LoadDotEnvOnce` panics if no `.env` file is found. In Kubernetes the
`.env` is mounted via ConfigMap so this works, but it makes local development
without a `.env` file crash ungracefully.

**Fix:** Log a warning and continue with environment variables only.

---

## Feature Request: Health check endpoint

The binary has no health check mechanism (no HTTP endpoint, no CLI subcommand).
This prevents Kubernetes liveness/readiness probes from verifying the capture
loop is running.

**Request:** Add a lightweight HTTP `/healthz` endpoint (or a `health` CLI
subcommand that exits 0 when the capture loop is active) to enable proper
Kubernetes health monitoring.
