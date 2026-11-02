/*
Consumer Credit Risk Portfolio Analysis
SQL Portfolio Analysis

Purpose:
Analyze historical LendingClub loan performance using SQL to identify
portfolio-level credit risk trends and borrower risk segments.
*/

-- =========================================================
-- 1. PORTFOLIO OVERVIEW
-- Calculates the core portfolio KPIs:
-- total loans, total originations, and observed default rate
-- =========================================================

SELECT
    COUNT(*) AS total_loans,
    ROUND(SUM(loan_amnt), 2) AS total_originations,
    ROUND(AVG(default_flag) * 100, 2) AS default_rate_pct
FROM loans;

-- =========================================================
-- 2. DEFAULT RATE BY CREDIT GRADE
-- Measures portfolio performance across LendingClub grades
-- =========================================================

SELECT
    grade,
    COUNT(*) AS total_loans,
    ROUND(SUM(loan_amnt), 2) AS total_originations,
    ROUND(AVG(default_flag) * 100, 2) AS default_rate_pct
FROM loans
GROUP BY grade
ORDER BY grade;

-- =========================================================
-- 3. DEFAULT RATE BY FICO BAND
-- Creates borrower risk segments using CASE WHEN
-- =========================================================

SELECT
    CASE
        WHEN fico >= 760 THEN '760+'
        WHEN fico >= 740 THEN '740-759'
        WHEN fico >= 720 THEN '720-739'
        WHEN fico >= 700 THEN '700-719'
        WHEN fico >= 680 THEN '680-699'
        WHEN fico >= 660 THEN '660-679'
        ELSE '<660'
    END AS fico_band,
    COUNT(*) AS total_loans,
    ROUND(AVG(default_flag) * 100, 2) AS default_rate_pct
FROM loans
GROUP BY
    CASE
        WHEN fico >= 760 THEN '760+'
        WHEN fico >= 740 THEN '740-759'
        WHEN fico >= 720 THEN '720-739'
        WHEN fico >= 700 THEN '700-719'
        WHEN fico >= 680 THEN '680-699'
        WHEN fico >= 660 THEN '660-679'
        ELSE '<660'
    END
ORDER BY MIN(fico) DESC;

-- =========================================================
-- 4. FICO × DTI RISK SEGMENTATION
-- Uses a CTE to create FICO and DTI risk bands, then
-- compares observed default rates across both dimensions
-- =========================================================

WITH risk_segments AS (
    SELECT
        default_flag,

        CASE
            WHEN fico >= 760 THEN '760+'
            WHEN fico >= 740 THEN '740-759'
            WHEN fico >= 720 THEN '720-739'
            WHEN fico >= 700 THEN '700-719'
            WHEN fico >= 680 THEN '680-699'
            WHEN fico >= 660 THEN '660-679'
            ELSE '<660'
        END AS fico_band,

        CASE
            WHEN dti < 10 THEN '0-10'
            WHEN dti < 20 THEN '10-20'
            WHEN dti < 30 THEN '20-30'
            WHEN dti < 40 THEN '30-40'
            ELSE '40+'
        END AS dti_band

    FROM loans
    WHERE fico IS NOT NULL
      AND dti IS NOT NULL
)

SELECT
    fico_band,
    dti_band,
    COUNT(*) AS total_loans,
    ROUND(AVG(default_flag) * 100, 2) AS default_rate_pct
FROM risk_segments
GROUP BY fico_band, dti_band
ORDER BY
    CASE fico_band
        WHEN '760+' THEN 1
        WHEN '740-759' THEN 2
        WHEN '720-739' THEN 3
        WHEN '700-719' THEN 4
        WHEN '680-699' THEN 5
        WHEN '660-679' THEN 6
        ELSE 7
    END,
    CASE dti_band
        WHEN '0-10' THEN 1
        WHEN '10-20' THEN 2
        WHEN '20-30' THEN 3
        WHEN '30-40' THEN 4
        ELSE 5
    END;


-- ============================================
-- 5. ADVANCED SQL: WINDOW FUNCTIONS
-- Credit Grade Risk Ranking
-- ============================================

WITH grade_performance AS (
    SELECT
        grade,
        COUNT(*) AS total_loans,
        ROUND(AVG(default_flag) * 100, 2) AS default_rate
    FROM loans
    GROUP BY grade
)

SELECT
    grade,
    total_loans,
    default_rate,
    RANK() OVER (
        ORDER BY default_rate DESC
    ) AS risk_rank, ROUND(
    SUM(default_rate * total_loans) OVER ()
    / SUM(total_loans) OVER (),
    2
) AS portfolio_default_rate, ROUND(
    default_rate -
    SUM(default_rate * total_loans) OVER ()
    / SUM(total_loans) OVER (),
    2
) AS variance_from_portfolio
FROM grade_performance
ORDER BY risk_rank;


-- ============================================
-- 6. ADVANCED SQL: JOINS
-- Credit Grade vs. Portfolio Benchmark
-- ============================================

WITH grade_performance AS (
    SELECT
        grade,
        COUNT(*) AS total_loans,
        ROUND(AVG(default_flag) * 100, 2) AS default_rate
    FROM loans
    GROUP BY grade
),
portfolio_benchmark AS (
    SELECT
        ROUND(AVG(default_flag) * 100, 2) AS portfolio_default_rate
    FROM loans
)

SELECT
    g.grade,
    g.total_loans,
    g.default_rate,
    p.portfolio_default_rate,
    ROUND(
        g.default_rate - p.portfolio_default_rate,
        2
    ) AS variance_from_portfolio
FROM grade_performance g
CROSS JOIN portfolio_benchmark p
ORDER BY g.default_rate DESC;


-- ============================================
-- 7. CREDIT POLICY SIMULATION
-- Evaluating Underwriting Thresholds
-- ============================================

WITH policy_scenarios AS (
    SELECT
        'Current Portfolio' AS scenario,
        COUNT(*) AS total_loans,
        ROUND(AVG(default_flag) * 100, 2) AS default_rate
    FROM loans

    UNION ALL

    SELECT
        'FICO >= 700' AS scenario,
        COUNT(*) AS total_loans,
        ROUND(AVG(default_flag) * 100, 2) AS default_rate
    FROM loans
    WHERE fico >= 700

    UNION ALL

    SELECT
        'FICO >= 720' AS scenario,
        COUNT(*) AS total_loans,
        ROUND(AVG(default_flag) * 100, 2) AS default_rate
    FROM loans
    WHERE fico >= 720
)

SELECT
    scenario,
    total_loans,
    default_rate,
    ROUND(
        total_loans * 100.0 /
        (SELECT COUNT(*) FROM loans),
        2
    ) AS retention_rate
FROM policy_scenarios;


