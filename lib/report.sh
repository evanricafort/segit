# Function to generate a comprehensive HTML report
generate_html_report() {
    local html_file="SegIt_Report.html"
    local date_str=$(date +%Y-%m-%d)
    
    # HTML Header
    cat << EOF > "$html_file"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SegIt! Network Segmentation Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f4f7f6; color: #333; }
        .container { max-width: 1000px; margin: auto; background: #fff; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.1); border-radius: 8px; }
        h1, h2, h3 { color: #2c3e50; }
        header { text-align: center; padding: 10px 0; border-bottom: 2px solid #e0e0e0; margin-bottom: 20px; }
        .section { margin-bottom: 30px; }
        .summary-table, .results-table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        .summary-table th, .summary-table td, .results-table th, .results-table td { padding: 12px 15px; text-align: left; border: 1px solid #ddd; }
        .summary-table th, .results-table th { background-color: #ecf0f1; font-weight: bold; }
        .pass { color: #27ae60; font-weight: bold; }
        .fail { color: #c0392b; font-weight: bold; }
        .info { background-color: #f0f3f5; padding: 10px; border-left: 5px solid #3498db; }
        pre { background: #ecf0f1; padding: 15px; border-radius: 5px; overflow-x: auto; white-space: pre-wrap; word-wrap: break-word; }
        .tab-menu { display: flex; border-bottom: 2px solid #ddd; }
        .tab-button { background-color: #f4f7f6; border: none; outline: none; cursor: pointer; padding: 14px 20px; transition: 0.3s; font-size: 16px; margin-right: 5px; border-top-left-radius: 5px; border-top-right-radius: 5px; }
        .tab-button:hover { background-color: #e2e4e6; }
        .tab-button.active { background-color: #fff; border: 1px solid #ddd; border-bottom: 1px solid #fff; }
        .tab-content { display: none; padding: 20px 0; border: 1px solid #ddd; border-top: none; }
        .tab-content.active { display: block; }
    </style>
</head>
<body>
<div class="container">
    <header>
        <h1>SegIt! Network Segmentation Test Report</h1>
        <p><strong>Date:</strong> $date_str</p>
    </header>

    <div class="section">
        <h2>Test Summary</h2>
        <div class="info">
            This report details the findings from network segmentation tests. It identifies open ports and services, along with verification attempts to confirm accessibility.
        </div>
        <table class="summary-table">
            <thead>
                <tr>
                    <th>Metric</th>
                    <th>Value</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>Total Targets</td>
                    <td>$(wc -l < all_targets.txt)</td>
                </tr>
                <tr>
                    <td>Live Hosts Found</td>
                    <td>$(wc -l < live_hosts.txt)</td>
                </tr>
                <tr>
                    <td>Total TCP Open Ports</td>
                    <td>$(awk '{print $1}' open_tcp_ports.txt | wc -l)</td>
                </tr>
                <tr>
                    <td>Total UDP Open Ports</td>
                    <td>$(awk '{print $1}' open_udp_ports.txt | wc -l)</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="section">
        <h2>Detailed Findings</h2>
        <div class="tab-menu">
            <button class="tab-button active" onclick="openTab(event, 'open-ports')">Open Ports</button>
            <button class="tab-button" onclick="openTab(event, 'netcat-verifications')">Netcat Verifications</button>
        </div>

        <div id="open-ports" class="tab-content active">
            <h3>TCP Open Ports</h3>
            <table class="results-table">
                <thead>
                    <tr>
                        <th>IP Address</th>
                        <th>Port</th>
                        <th>Service</th>
                    </tr>
                </thead>
                <tbody>
EOF
    # Populate TCP ports table from Nmap XML
    if [ -f "nmap_output_files/service_scan.xml" ]; then
        nmap_xml_parser "nmap_output_files/service_scan.xml" "tcp" >> "$html_file"
    fi
    
    cat << EOF >> "$html_file"
                </tbody>
            </table>

            <h3>UDP Open Ports</h3>
            <table class="results-table">
                <thead>
                    <tr>
                        <th>IP Address</th>
                        <th>Port</th>
                        <th>Service</th>
                    </tr>
                </thead>
                <tbody>
EOF
    # Populate UDP ports table from Nmap XML
    if [ -f "nmap_output_files/udp_scan.xml" ]; then
        nmap_xml_parser "nmap_output_files/udp_scan.xml" "udp" >> "$html_file"
    fi

    cat << EOF >> "$html_file"
                </tbody>
            </table>
        </div>

        <div id="netcat-verifications" class="tab-content">
            <h3>TCP Verification Results</h3>
            <pre>$(cat tcp_netcat_results.txt)</pre>
            
            <h3>UDP Verification Results</h3>
            <pre>$(cat udp_netcat_results.txt)</pre>
        </div>
    </div>
    
    <div class="section">
        <h2>Raw Scan Data</h2>
        <p>For detailed analysis, refer to the original Nmap output files located in the <code>nmap_output_files</code> directory.</p>
    </div>

    <footer>
        <p style="text-align: center; color: #95a5a6;">Generated by SegIt! on $date_str</p>
    </footer>

    <script>
        function openTab(evt, tabName) {
            var i, tabcontent, tabbuttons;
            tabcontent = document.getElementsByClassName("tab-content");
            for (i = 0; i < tabcontent.length; i++) {
                tabcontent[i].style.display = "none";
            }
            tabbuttons = document.getElementsByClassName("tab-button");
            for (i = 0; i < tabbuttons.length; i++) {
                tabbuttons[i].className = tabbuttons[i].className.replace(" active", "");
            }
            document.getElementById(tabName).style.display = "block";
            evt.currentTarget.className += " active";
        }
    </script>
</div>
</body>
</html>
EOF
    echo -e "${GREEN}HTML report generated at ${YELLOW}$(pwd)/$html_file${NC}"
}

# Helper function to parse Nmap XML and format for HTML
nmap_xml_parser() {
    local xml_file="$1"
    local proto="$2"
    if [ -f "$xml_file" ]; then
        grep -oP '<host .*?</host>' "$xml_file" | while read -r host_line; do
            ip=$(echo "$host_line" | grep -oP '(?<=addr=").*?(?=")')
            echo "$host_line" | grep -oP '<port protocol="'"$proto"'" portid=".*?">.*?</port>' | while read -r port_line; do
                port=$(echo "$port_line" | grep -oP '(?<=portid=").*?(?=")')
                service=$(echo "$port_line" | grep -oP '(?<=<service name=").*?(?=")')
                echo "<tr><td>$ip</td><td>$port</td><td>$service</td></tr>"
            done
        done
    fi
}