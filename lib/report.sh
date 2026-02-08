# File: lib/report.sh

generate_html_report() {
    local targets="$1"
    local targets_file="$2"
    local start_time="$3"
    local end_time="$4"
    local duration="$5"
    local traffic_from="$6"
    local html_file="SegIt_Report.html"
    
    # --- Data Collection ---
    local total_targets_count=0
    [ -f "all_targets.txt" ] && total_targets_count=$(wc -l < "all_targets.txt")
    
    local live_hosts_count=0
    [ -f "live_hosts.txt" ] && live_hosts_count=$(wc -l < "live_hosts.txt")

    local all_targets_content="No targets file found."
    [ -f "all_targets.txt" ] && all_targets_content=$(cat "all_targets.txt")

    # Count PASS and FAIL
    local pass_count=0
    local fail_count=0
    
    if [ -f "segmentation_results_run1.csv" ] && [ -f "segmentation_results_run2.csv" ]; then
        # Count from both files in compare mode (or just the latest? usually total findings)
        # We will count unique findings per run to give a sense of volume
        pass_count=$(grep -c ",PASS," segmentation_results_run*.csv | awk -F: '{sum+=$2} END {print sum}')
        fail_count=$(grep -c ",FAIL," segmentation_results_run*.csv | awk -F: '{sum+=$2} END {print sum}')
    elif [ -f "segmentation_results.csv" ]; then
        pass_count=$(grep -c ",PASS," segmentation_results.csv)
        fail_count=$(grep -c ",FAIL," segmentation_results.csv)
    fi

    # --- HTML Generation ---
    cat << EOF > "$html_file"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>SegIt! Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f4f7f6; color: #333; }
        .container { max-width: 1200px; margin: auto; background: #fff; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.1); border-radius: 8px; }
        h1, h2, h3 { color: #2c3e50; }
        header { text-align: center; border-bottom: 2px solid #e0e0e0; margin-bottom: 20px; }
        .section { margin-bottom: 30px; }
        .info { background-color: #f0f3f5; padding: 10px; border-left: 5px solid #3498db; margin-bottom: 15px; }
        pre { background: #ecf0f1; padding: 10px; border-radius: 5px; }
        .verif-table { width: 100%; border-collapse: collapse; font-size: 0.9em; margin-bottom: 20px; }
        .verif-table th, .verif-table td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        .verif-table th { background-color: #34495e; color: white; }
        .pass { background-color: #e8f8f5; color: #27ae60; font-weight: bold; }
        .fail { background-color: #fadbd8; color: #c0392b; font-weight: bold; }
        .summary-table { width: 100%; border-collapse: collapse; }
        .summary-table th, .summary-table td { padding: 12px; border: 1px solid #ddd; text-align: left; }
        .live-hosts-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px; }
        .host-item { background: #ecf0f1; padding: 8px; text-align: center; border-radius: 4px; font-family: monospace; }
        .run-label { font-size: 0.85em; color: #555; font-weight: bold; display: block; margin-top: 4px; }
    </style>
</head>
<body>
<div class="container">
    <header>
        <h1>SegIt! Network Segmentation Test Report</h1>
        <p><strong>Started:</strong> $start_time | <strong>Finished:</strong> $end_time | <strong>Duration:</strong> $duration</p>
        <p><strong>Traffic Origin:</strong> $traffic_from</p>
    </header>
    
    <div class="section">
        <h2>Test Summary</h2>
        <table class="summary-table">
            <tr>
                <th>Total Targets</th>
                <td>$total_targets_count</td>
                <th>Live Hosts</th>
                <td>$live_hosts_count</td>
            </tr>
            <tr>
                <th>Total PASS</th>
                <td style="color: #27ae60; font-weight:bold;">$pass_count</td>
                <th>Total FAIL</th>
                <td style="color: #c0392b; font-weight:bold;">$fail_count</td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>Live Hosts Detected</h2>
        <div class="live-hosts-grid">
EOF
    if [ -s "live_hosts.txt" ]; then
        while read -r host; do
            echo "<div class='host-item'>$host</div>" >> "$html_file"
        done < "live_hosts.txt"
    else
        echo "<p>No live hosts detected.</p>" >> "$html_file"
    fi
cat << EOF >> "$html_file"
        </div>
    </div>

    <div class="section">
        <h2>Segmentation Verification Results</h2>
        <div class="info">
            <strong>PASS:</strong> Connection Blocked. <strong>FAIL:</strong> Connection Allowed (Risk).
        </div>
        <table class="verif-table">
            <thead>
                <tr>
                    <th>Traffic From</th>
                    <th>Traffic To</th>
                    <th>Status</th>
                    <th>Dest IP</th>
                    <th>Port</th>
                    <th>Notes</th>
                </tr>
            </thead>
            <tbody>
EOF

    # === DYNAMIC MERGING & REPORTING LOGIC ===
    if [ -f "segmentation_results_run1.csv" ] && [ -f "segmentation_results_run2.csv" ]; then
        # --- MERGED COMPARISON TABLE ---
        # Use awk to join files based on Destination IP ($5) and Port ($6)
        # It buffers Run 1 and then merges with Run 2
        
        awk -F, '
        NR==FNR {
            # Store Run 1 Data. Key = DestIP_Port
            key=$5"_"$6
            status[key]=$3
            notes[key]=$7
            # Keep other fields for printing
            full_line[key]=$0
            t_from[key]=$1
            t_to[key]=$2
            src_ip[key]=$4
            dst_ip[key]=$5
            port[key]=$6
            next
        }
        {
            # Process Run 2
            key=$5"_"$6
            current_status=$3
            current_note=$7
            
            # Formatting CSS class
            class_attr=""
            if (current_status == "FAIL") class_attr="class=\047fail\047"
            else if (current_status == "PASS") class_attr="class=\047pass\047"
            
            # Merge Notes
            combined_notes=""
            if (key in notes) {
                combined_notes="<span class=\047run-label\047>Run 1:</span> " notes[key] "<br><span class=\047run-label\047>Run 2:</span> " current_note
                # Remove from array so we know it was processed
                delete notes[key]
            } else {
                combined_notes="<span class=\047run-label\047>Run 1:</span> N/A (Not Scanned)<br><span class=\047run-label\047>Run 2:</span> " current_note
            }
            
            # Print Merged Row (Using Run 2 status as current status)
            if ($1 != "Traffic From") {
                print "<tr><td>" $1 "</td><td>" $2 "</td><td " class_attr ">" current_status "</td><td>" $5 "</td><td>" $6 "</td><td>" combined_notes "</td></tr>"
            }
        }
        END {
            # Print remaining items from Run 1 that were NOT in Run 2
            for (key in notes) {
                 class_attr=""
                 if (status[key] == "FAIL") class_attr="class=\047fail\047"
                 else if (status[key] == "PASS") class_attr="class=\047pass\047"
                 
                 combined_notes="<span class=\047run-label\047>Run 1:</span> " notes[key] "<br><span class=\047run-label\047>Run 2:</span> N/A (Not Scanned)"
                 
                 if (t_from[key] != "Traffic From") {
                    print "<tr><td>" t_from[key] "</td><td>" t_to[key] "</td><td " class_attr ">" status[key] "</td><td>" dst_ip[key] "</td><td>" port[key] "</td><td>" combined_notes "</td></tr>"
                 }
            }
        }
        ' segmentation_results_run1.csv segmentation_results_run2.csv >> "$html_file"

    else
        # --- STANDARD SINGLE RUN ---
        if [ -f "segmentation_results.csv" ]; then
            while IFS=, read -r t_from t_to status src_ip dst_ip port notes; do
                if [[ "$t_from" == "Traffic From" ]]; then continue; fi
                class_attr=""
                [[ "$status" == "FAIL" ]] && class_attr="class='fail'"
                [[ "$status" == "PASS" ]] && class_attr="class='pass'"
                echo "<tr><td>$t_from</td><td>$t_to</td><td $class_attr>$status</td><td>$dst_ip</td><td>$port</td><td>$notes</td></tr>" >> "$html_file"
            done < "segmentation_results.csv"
        else
             echo "<tr><td colspan='6'>No results found.</td></tr>" >> "$html_file"
        fi
    fi

    cat << EOF >> "$html_file"
            </tbody>
        </table>
    </div>

    <footer>
        <p style="text-align: center; color: #95a5a6;">Generated by <a href="https://github.com/evanricafort/segit">SegIt!</a> - Automated Network Segmentation Testing Toolkit</p>
    </footer>
</div>
</body>
</html>
EOF
    echo -e "${GREEN}HTML report generated at ${YELLOW}$(pwd)/$html_file${NC}"
}
