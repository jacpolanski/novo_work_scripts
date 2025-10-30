// ==UserScript==
// @name         RCP Home Page - Enhanced
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  Live work analysis on home page
// @author       You
// @match        https://rcp.novomatic-tech.com/Home.aspx
// @match        https://rcp.novomatic-tech.com/default.aspx
// @grant        none
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    // Wait for page to be ready
    if (!document.querySelector('#headMenuRight ul').children.length) {
        setTimeout(arguments.callee, 100);
        return;
    }

    const DAILY_HOURS = 8;
    const DAILY_SECONDS = DAILY_HOURS * 3600;

    // Utilities
    function parseTimeToSeconds(timeStr) {
        if (!timeStr || timeStr.trim() === '') return 0;
        const parts = timeStr.trim().split(':');
        if (parts.length < 2) return 0;
        const hours = parseInt(parts[0]) || 0;
        const minutes = parseInt(parts[1]) || 0;
        const seconds = parseInt(parts[2]) || 0;
        return hours * 3600 + minutes * 60 + seconds;
    }

    function formatTime(seconds) {
        const sign = seconds < 0 ? '-' : '';
        const abs = Math.abs(seconds);
        const hours = Math.floor(abs / 3600);
        const minutes = Math.floor((abs % 3600) / 60);
        return `${sign}${hours}h ${minutes}m`;
    }

    function formatClock(seconds) {
        // Handle negative values and wrap around 24h format
        let totalSecs = seconds;
        if (totalSecs < 0) totalSecs = (24 * 3600) + totalSecs; // wrap negative to next day
        totalSecs = totalSecs % (24 * 3600); // wrap to 24h format

        const hours = Math.floor(totalSecs / 3600);
        const minutes = Math.floor((totalSecs % 3600) / 60);
        const secs = Math.floor(totalSecs % 60);
        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }

    function getCurrentTime() {
        const now = new Date();
        return now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds();
    }

    function addSecondsToTime(timeStr, seconds) {
        const baseSeconds = parseTimeToSeconds(timeStr);
        const totalSeconds = baseSeconds + seconds;
        return formatClock(totalSeconds);
    }

    // Add custom styles
    const style = document.createElement('style');
    style.innerHTML = `
        .work-status {
            background: white;
            padding: 20px;
            margin: 16px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            font-family: Roboto, sans-serif;
        }
        .status-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
            margin-top: 12px;
        }
        .status-item {
            padding: 16px;
            border-radius: 6px;
            text-align: center;
            border-left: 4px solid;
        }
        .status-item.positive {
            background: rgba(76, 175, 80, 0.1);
            border-left-color: #4CAF50;
        }
        .status-item.negative {
            background: rgba(244, 67, 54, 0.1);
            border-left-color: #F44336;
        }
        .status-item.neutral {
            background: rgba(33, 150, 243, 0.1);
            border-left-color: #2196F3;
        }
        .status-value {
            font-size: 18px;
            font-weight: 500;
            margin-bottom: 4px;
        }
        .status-label {
            font-size: 12px;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .balance-indicator {
            text-align: center;
            padding: 12px;
            margin: 12px 0;
            border-radius: 6px;
            font-size: 16px;
            font-weight: 500;
        }
        .balance-indicator.positive {
            background: linear-gradient(135deg, rgba(255, 193, 7, 0.15), rgba(255, 152, 0, 0.15));
            border-left: 4px solid #FF9800;
            color: #E65100;
            box-shadow: 0 0 15px rgba(255, 152, 0, 0.3);
            border: 1px solid rgba(255, 152, 0, 0.4);
        }
        .balance-indicator.negative {
            background: rgba(244, 67, 54, 0.1);
            border-left: 4px solid #F44336;
            color: #C62828;
        }
        .balance-indicator.neutral {
            background: rgba(33, 150, 243, 0.1);
            border-left: 4px solid #2196F3;
            color: #1565C0;
        }
        .last-update {
            font-size: 11px;
            color: #999;
            text-align: right;
            margin-top: 8px;
        }
        @media (max-width: 600px) {
            .status-grid {
                grid-template-columns: 1fr;
            }
        }
    `;
    document.head.appendChild(style);

    let workData = {
        startTime: null,
        monthlyBalance: 0,
        absenceDays: 0
    };

    // Get start time from page
    function getStartTime() {
        // Try multiple selectors to find start time
        let logElement = document.querySelector('#log strong:last-child');
        if (!logElement) {
            logElement = $("#log strong:last").get(0); // jQuery selector like in original
        }
        if (logElement) {
            workData.startTime = logElement.textContent.trim();
            console.log('Start time found:', workData.startTime);
        } else {
            console.log('Start time element not found');
        }
    }

    // Fetch monthly data
    function fetchMonthlyData() {
        if (!workData.startTime) return;

        jQuery.ajax({
            url: "https://rcp.novomatic-tech.com/Rcp.aspx/MyViewRegistrationsCustomize",
            success: function(result) {
                const tempDiv = $('<div>').html(result);

                // Count absence days
                let absenceDays = 0;
                tempDiv.find('.tablecell').each(function() {
                    const absenceCell = $(this).find('td:nth-child(2)');
                    if (absenceCell.length && absenceCell.text().trim() !== '') {
                        absenceDays++;
                    }
                });

                // Get monthly totals
                const summary = tempDiv.find('.tablesummary');
                if (summary.length) {
                    const normaText = summary.find('td:nth-child(3)').text().trim();
                    const zaliczText = summary.find('td:nth-child(4)').text().trim();

                    const normaSeconds = parseTimeToSeconds(normaText);
                    const zaliczSeconds = parseTimeToSeconds(zaliczText);

                    workData.monthlyBalance = zaliczSeconds - normaSeconds;
                    workData.absenceDays = absenceDays;
                }

                updateDisplay();
            }
        });
    }

    // Update the display
    function updateDisplay() {
        const container = document.querySelector('#contContent');
        if (!container || !workData.startTime) return;

        // Remove existing display
        const existing = container.querySelector('.work-status');
        if (existing) existing.remove();

        const currentTime = getCurrentTime();
        const startSeconds = parseTimeToSeconds(workData.startTime);
        const workedToday = currentTime - startSeconds;

        // When to leave for 8 hours (start time + 8h)
        const leaveFor8h = addSecondsToTime(workData.startTime, DAILY_SECONDS);

        // When to leave considering overtime (start time + 8h - overtime already earned)
        const adjustedLeaveTime = addSecondsToTime(workData.startTime, DAILY_SECONDS - workData.monthlyBalance);

        // Debug logging
        console.log('Debug RCP:', {
            startTime: workData.startTime,
            startSeconds: startSeconds,
            monthlyBalance: workData.monthlyBalance,
            DAILY_SECONDS,
            'startSeconds + DAILY_SECONDS': startSeconds + DAILY_SECONDS,
            leaveFor8h,
            adjustedLeaveTime
        });

        // Manual test
        console.log('Manual test:');
        console.log('parseTimeToSeconds("07:34:00"):', parseTimeToSeconds("07:34:00"));
        console.log('27240 + 28800 =', 27240 + 28800);
        console.log('formatClock(56040):', formatClock(56040));
        console.log('addSecondsToTime("07:34:00", 28800):', addSecondsToTime("07:34:00", 28800));

        // Balance status
        const balanceClass = workData.monthlyBalance > 0 ? 'positive' : workData.monthlyBalance < 0 ? 'negative' : 'neutral';
        const balanceText = workData.monthlyBalance > 0 ? '⭐ Nadgodziny' : workData.monthlyBalance < 0 ? 'Do tyłu' : 'Na zero';

        const display = document.createElement('div');
        display.className = 'work-status';

        display.innerHTML = `
            <div class="balance-indicator ${balanceClass}">
                ${balanceText}: ${formatTime(Math.abs(workData.monthlyBalance))}
            </div>
            <div class="status-grid">
                <div class="status-item neutral">
                    <div class="status-value">${leaveFor8h}</div>
                    <div class="status-label">Start + 8h</div>
                </div>
                <div class="status-item ${balanceClass}">
                    <div class="status-value">${adjustedLeaveTime}</div>
                    <div class="status-label">Z nadgodzinami</div>
                </div>
            </div>
            ${workData.absenceDays > 0 ? `
            <div style="text-align: center; margin-top: 12px; font-size: 14px; color: #666;">
                Dni nieobecności w tym miesiącu: <strong>${workData.absenceDays}</strong>
            </div>
            ` : ''}
            <div class="last-update">
                Zaktualizowano: ${new Date().toLocaleTimeString()}
            </div>
        `;

        container.appendChild(display);
    }

    // Initialize
    function init() {
        getStartTime();
        if (workData.startTime) {
            fetchMonthlyData();

            // Auto-refresh every 5 minutes
            setInterval(function() {
                fetchMonthlyData();
            }, 5 * 60 * 1000);

            // Update display every minute for current time calculations
            setInterval(updateDisplay, 60 * 1000);
        }
    }

    // Wait a bit for the page to stabilize
    setTimeout(init, 1000);

})();
