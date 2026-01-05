# gdig - Global DNS Checker

A bash script that queries DNS records from multiple DNS servers worldwide using the [whatsmydns.net](https://www.whatsmydns.net) API.

## Features

- **Parallel Processing**: Uses GNU Parallel for concurrent DNS queries
- **Global Coverage**: Query DNS servers from 20+ countries
- **Local DNS Check**: Also checks against Cloudflare, Google, OpenDNS, and Korean ISP DNS servers
- **Caching**: 24-hour cache for DNS server list
- **Dynamic Table Output**: Auto-adjusts to terminal width
- **Country Filter**: Filter results by country code

## Requirements

```bash
# macOS
brew install curl jq bind parallel

# Ubuntu/Debian
sudo apt install curl jq dnsutils parallel
```

## Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/scripts.git
cd scripts

# Make executable
chmod +x gdig.sh

# Optional: Add to PATH
sudo ln -s $(pwd)/gdig.sh /usr/local/bin/gdig
```

## Usage

```bash
./gdig.sh <type> <domain> [country]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `type` | DNS record type (A, AAAA, CNAME, MX, NS, TXT, SOA, etc.) |
| `domain` | Domain name to query |
| `country` | (Optional) Two-letter country code to filter servers |

### Examples

```bash
# Query A record globally
./gdig.sh a www.example.com

# Query from South Korea only
./gdig.sh a www.example.com kr

# Query MX record from US servers
./gdig.sh mx example.com us

# Query CNAME record
./gdig.sh cname www.example.com
```

### Options

```bash
./gdig.sh --list-countries    # Show available country codes
./gdig.sh --clear-cache       # Clear the server cache
./gdig.sh --help              # Show help message
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GDIG_WIDTH` | Force specific terminal width | Auto-detect |

```bash
# Force 200 character width
GDIG_WIDTH=200 ./gdig.sh a example.com
```

## Supported Countries

AU, BR, CA, CN, DE, ES, FR, GB, IN, KR, MX, MY, NL, PK, RU, SG, TH, TR, US, ZA

## Sample Output

```
Global DNS Checker - www.example.com (A)

  Query:   A record for www.example.com
  Filter:  Country = US
  Source:  whatsmydns.net API

+----------------------------------+------------------+--------------------------------------------------+
| DNS Server                       | Provider         | Response                                         |
+----------------------------------+------------------+--------------------------------------------------+
| [US] Ashburn VA, United States   | NeuStar          | 93.184.216.34                                    |
| [US] Boston MA, United States    | Speakeasy        | 93.184.216.34                                    |
+----------------------------------+------------------+--------------------------------------------------+

Summary: 5 servers queried | 5 successful | 1 unique responses

DNS check completed successfully
```

## License

MIT License

## Author

- **Lee Sanghun** ([@YOUR_GITHUB](https://github.com/YOUR_USERNAME))
