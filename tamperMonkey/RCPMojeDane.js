// ==UserScript==
// @name         RCP Moje Dane - Overtime Analyzer
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  Analyze overtime and work balance on Moje Dane page
// @author       You
// @match        https://rcp.novomatic-tech.com/Rcp.aspx/MyViewRegistrationsCustomize*
// @grant        none
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';
    
    // Wait for table to be ready
    if (!document.querySelector('table.tabela')) {
        setTimeout(arguments.callee, 100);
        return;
    }
    
    // Configuration
    const DAILY_HOURS = 8; // 8 hours per day
    const DAILY_SECONDS = DAILY_HOURS * 3600;
    
    // Utilities
    function parseTimeToSeconds(timeStr) {
        if (!timeStr || timeStr.trim() === '' || timeStr.trim() === '-') return 0;
        const parts = timeStr.trim().split(':');
        if (parts.length < 2) return 0;
        const hours = parseInt(parts[0]) || 0;
        const minutes = parseInt(parts[1]) || 0;
        return hours * 3600 + minutes * 60;
    }
    
    function formatTime(seconds) {
        const sign = seconds < 0 ? '-' : '';
        const abs = Math.abs(seconds);
        const hours = Math.floor(abs / 3600);
        const minutes = Math.floor((abs % 3600) / 60);
        return `${sign}${hours}h ${minutes}m`;
    }
    
    function formatTimeHM(seconds) {
        const sign = seconds < 0 ? '-' : '';
        const abs = Math.abs(seconds);
        const hours = Math.floor(abs / 3600);
        const minutes = Math.floor((abs % 3600) / 60);
        return `${sign}${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
    }
    
    // Add custom styles
    const style = document.createElement('style');
    style.innerHTML = `
        .overtime-badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 500;
            margin-left: 8px;
            font-family: Roboto, sans-serif;
        }
        .overtime-badge.positive {
            background: rgba(76, 175, 80, 0.1);
            color: #4CAF50;
            border: 1px solid rgba(76, 175, 80, 0.3);
        }
        .overtime-badge.negative {
            background: rgba(244, 67, 54, 0.1);
            color: #F44336;
            border: 1px solid rgba(244, 67, 54, 0.3);
        }
        .overtime-badge.neutral {
            background: rgba(158, 158, 158, 0.1);
            color: #9E9E9E;
            border: 1px solid rgba(158, 158, 158, 0.3);
        }
        .overtime-summary {
            background: white;
            padding: 16px;
            margin: 16px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            font-family: Roboto, sans-serif;
        }
        .overtime-summary h3 {
            margin: 0 0 12px 0;
            color: #2d4e7c;
            font-size: 16px;
            font-weight: 500;
        }
        .overtime-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 12px;
        }
        .overtime-stat {
            padding: 12px;
            border-radius: 4px;
            text-align: center;
        }
        .overtime-stat.positive {
            background: rgba(76, 175, 80, 0.1);
            border-left: 4px solid #4CAF50;
        }
        .overtime-stat.negative {
            background: rgba(244, 67, 54, 0.1);
            border-left: 4px solid #F44336;
        }
        .overtime-stat.neutral {
            background: rgba(158, 158, 158, 0.1);
            border-left: 4px solid #9E9E9E;
        }
        .overtime-stat-value {
            font-size: 18px;
            font-weight: 500;
            margin-bottom: 4px;
        }
        .overtime-stat-label {
            font-size: 12px;
            color: #666;
            text-transform: uppercase;
        }
        .filter-controls {
            background: white;
            padding: 12px 16px;
            margin: 16px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            font-family: Roboto, sans-serif;
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            align-items: center;
        }
        .filter-btn {
            padding: 6px 12px;
            border: 1px solid #ddd;
            border-radius: 4px;
            background: white;
            cursor: pointer;
            font-size: 12px;
            font-family: Roboto, sans-serif;
            transition: all 0.2s;
        }
        .filter-btn:hover {
            background: #f5f5f5;
        }
        .filter-btn.active {
            background: #2d4e7c;
            color: white;
            border-color: #2d4e7c;
        }
        .filter-label {
            font-size: 12px;
            color: #666;
            font-weight: 500;
        }
        .day-row.overtime {
            background-color: rgba(76, 175, 80, 0.05) !important;
        }
        .day-row.undertime {
            background-color: rgba(244, 67, 54, 0.05) !important;
        }
        .absence-badge {
            display: inline-block;
            padding: 2px 6px;
            border-radius: 8px;
            font-size: 10px;
            font-weight: 500;
            background: rgba(33, 150, 243, 0.1);
            color: #2196F3;
            border: 1px solid rgba(33, 150, 243, 0.3);
        }
    `;
    document.head.appendChild(style);
    
    // Analyze table data
    function analyzeWorkData() {
        const table = document.querySelector('table.tabela');
        if (!table) return;
        
        const dataRows = table.querySelectorAll('tr.tablecell');
        const summaryRow = table.querySelector('tr.tablesummary');
        
        let totalOvertime = 0;
        let workDays = 0;
        let overtimeDays = 0;
        let undertimeDays = 0;
        let exactDays = 0;
        let absenceDays = 0;
        
        // Process each day
        dataRows.forEach((row, index) => {
            if (index === 0) return; // Skip navigation row
            
            const cells = row.querySelectorAll('td');
            if (cells.length < 4) return;
            
            const dateCell = cells[0];
            const absenceCell = cells[1];
            const normaCell = cells[2];
            const zaliczCell = cells[3];
            
            const normaSeconds = parseTimeToSeconds(normaCell.textContent);
            const zaliczSeconds = parseTimeToSeconds(zaliczCell.textContent);
            const absenceText = absenceCell.textContent.trim();
            
            // Skip weekend/holiday rows (0:00 norma)
            if (normaSeconds === 0) return;
            
            workDays++;
            const difference = zaliczSeconds - normaSeconds;
            totalOvertime += difference;
            
            // Add absence badge if present
            if (absenceText && absenceText !== '') {
                const badge = document.createElement('span');
                badge.className = 'absence-badge';
                badge.textContent = absenceText;
                absenceCell.innerHTML = '';
                absenceCell.appendChild(badge);
                absenceDays++;
            }
            
            // Add overtime badge
            let badge = document.createElement('span');
            badge.className = 'overtime-badge';
            
            if (difference > 0) {
                badge.classList.add('positive');
                badge.textContent = `+${formatTime(difference)}`;
                row.classList.add('overtime');
                overtimeDays++;
            } else if (difference < 0) {
                badge.classList.add('negative');
                badge.textContent = formatTime(difference);
                row.classList.add('undertime');
                undertimeDays++;
            } else {
                badge.classList.add('neutral');
                badge.textContent = '0h 0m';
                exactDays++;
            }
            
            zaliczCell.appendChild(badge);
        });
        
        // Create summary
        createOvertimeSummary(totalOvertime, workDays, overtimeDays, undertimeDays, exactDays, absenceDays);
        
        // Enhance existing summary row
        if (summaryRow) {
            const cells = summaryRow.querySelectorAll('td');
            if (cells.length >= 4) {
                const normaTotal = parseTimeToSeconds(cells[2].textContent);
                const zaliczTotal = parseTimeToSeconds(cells[3].textContent);
                const monthlyBalance = zaliczTotal - normaTotal;
                
                const badge = document.createElement('span');
                badge.className = 'overtime-badge';
                if (monthlyBalance > 0) {
                    badge.classList.add('positive');
                    badge.textContent = `+${formatTime(monthlyBalance)}`;
                } else if (monthlyBalance < 0) {
                    badge.classList.add('negative');
                    badge.textContent = formatTime(monthlyBalance);
                } else {
                    badge.classList.add('neutral');
                    badge.textContent = '0h 0m';
                }
                cells[3].appendChild(badge);
            }
        }
    }
    
    function createOvertimeSummary(totalOvertime, workDays, overtimeDays, undertimeDays, exactDays, absenceDays) {
        const summary = document.createElement('div');
        summary.className = 'overtime-summary';
        
        summary.innerHTML = `
            <h3>📊 Analiza czasu pracy</h3>
            <div class="overtime-stats">
                <div class="overtime-stat ${totalOvertime >= 0 ? 'positive' : 'negative'}">
                    <div class="overtime-stat-value">${formatTime(totalOvertime)}</div>
                    <div class="overtime-stat-label">Bilans całkowity</div>
                </div>
                <div class="overtime-stat neutral">
                    <div class="overtime-stat-value">${absenceDays}</div>
                    <div class="overtime-stat-label">Dni nieobecności</div>
                </div>
            </div>
        `;
        
        // Insert summary before the table
        const table = document.querySelector('table.tabela');
        if (table && table.parentNode) {
            table.parentNode.insertBefore(summary, table);
        }
    }
    
    function createFilterControls() {
        const filters = document.createElement('div');
        filters.className = 'filter-controls';
        
        filters.innerHTML = `
            <span class="filter-label">Filtry:</span>
            <button class="filter-btn" data-filter="all">Wszystkie dni</button>
            <button class="filter-btn" data-filter="overtime">Tylko nadgodziny</button>
            <button class="filter-btn" data-filter="undertime">Tylko niedobory</button>
            <button class="filter-btn" data-filter="workdays">Bez weekendów</button>
            <button class="filter-btn" data-filter="absence">Tylko nieobecności</button>
        `;
        
        // Add event listeners
        filters.addEventListener('click', function(e) {
            if (e.target.classList.contains('filter-btn')) {
                // Remove active class from all buttons
                filters.querySelectorAll('.filter-btn').forEach(btn => btn.classList.remove('active'));
                
                // Add active class to clicked button
                e.target.classList.add('active');
                
                // Apply filter
                applyFilter(e.target.dataset.filter);
            }
        });
        
        // Set default active filter
        filters.querySelector('[data-filter="all"]').classList.add('active');
        
        // Insert before the table
        const table = document.querySelector('table.tabela');
        if (table && table.parentNode) {
            table.parentNode.insertBefore(filters, table);
        }
    }
    
    function applyFilter(filterType) {
        const table = document.querySelector('table.tabela');
        if (!table) return;
        
        const dataRows = table.querySelectorAll('tr.tablecell');
        
        dataRows.forEach((row, index) => {
            if (index === 0) {
                // Always show navigation row
                row.style.display = '';
                return;
            }
            
            const cells = row.querySelectorAll('td');
            if (cells.length < 4) {
                row.style.display = '';
                return;
            }
            
            const absenceCell = cells[1];
            const normaCell = cells[2];
            const zaliczCell = cells[3];
            
            const normaSeconds = parseTimeToSeconds(normaCell.textContent);
            const zaliczSeconds = parseTimeToSeconds(zaliczCell.textContent);
            const absenceText = absenceCell.textContent.trim();
            const difference = zaliczSeconds - normaSeconds;
            
            let show = false;
            
            switch(filterType) {
                case 'all':
                    show = true;
                    break;
                case 'overtime':
                    show = normaSeconds > 0 && difference > 0;
                    break;
                case 'undertime':
                    show = normaSeconds > 0 && difference < 0;
                    break;
                case 'workdays':
                    show = normaSeconds > 0;
                    break;
                case 'absence':
                    show = absenceText && absenceText !== '';
                    break;
            }
            
            row.style.display = show ? '' : 'none';
        });
    }
    
    // Run analysis
    analyzeWorkData();
    createFilterControls();
    
})();
