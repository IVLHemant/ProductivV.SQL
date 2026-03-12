INSERT INTO dbo.BU_Summary
(
    SummaryDate,
    InstanceID,
    BusinessUnitGroup,
    TotalEmployees,
    BenchEmployees,
    TotalBillableEmployees,
    TotalNonBillableEmployees,
    TotalMaternityLeaves,
    TotalEmployeesWithEnablingUnit,
    BGVCandidates
)

SELECT
    CAST(GETDATE() AS DATE) AS SummaryDate,

    e.InstanceID,

    b.BusinessUnitGroup,

    -- Total Active Employees
    COUNT(DISTINCT CASE 
        WHEN e.IsActive = 1 THEN e.ID 
    END) AS TotalEmployees,

    -- Bench Employees
    COUNT(DISTINCT CASE 
        WHEN e.IsActive = 1 
         AND e.ProjectID = 56 
        THEN e.ID 
    END) AS BenchEmployees,

    -- Billable Employees
    COUNT(DISTINCT CASE 
        WHEN e.IsActive = 1 
         AND e.IsBillable = 1 
        THEN e.ID 
    END) AS TotalBillableEmployees,

    -- Non-Billable Employees
    COUNT(DISTINCT CASE 
        WHEN e.IsActive = 1 
         AND e.IsBillable = 0 
        THEN e.ID 
    END) AS TotalNonBillableEmployees,

    -- Current Approved Maternity Leave
    COUNT(DISTINCT CASE
        WHEN e.IsActive = 1
         AND lh.LeaveName = 'Maternity Leave'
         AND lh.LeaveStatus = 'Approved'
         AND GETDATE() BETWEEN lh.StartDate AND lh.ToDate
        THEN e.ID
    END) AS TotalMaternityLeaves,

    -- Employees With Enabling Unit
    COUNT(DISTINCT CASE 
        WHEN e.IsActive = 1 
         AND e.EnablingUnitId IS NOT NULL 
        THEN e.ID 
    END) AS TotalEmployeesWithEnablingUnit,

    -- BGV Candidates grouped by BU
    ISNULL(bgv.BGVCandidates,0) AS BGVCandidates

FROM PeP_DB_06Feb2026.dbo.Employee e

INNER JOIN PeP_DB_06Feb2026.dbo.BusinessUnitMaster b
    ON e.BusinessUnitID = b.ID
   AND e.InstanceID = b.InstanceID

LEFT JOIN PeP_DB_06Feb2026.dbo.LeaveHistory lh
    ON lh.EmployeeID = e.ID
   AND lh.InstanceID = e.InstanceID

LEFT JOIN
(
    SELECT
        e.InstanceID,
        e.BusinessUnitID,
        COUNT(*) AS BGVCandidates
    FROM PeP_DB_06Feb2026.dbo.CandidateBGVHistory b
    INNER JOIN PeP_DB_06Feb2026.dbo.HireCandidate h
        ON b.HireCandidateID = h.ID
    INNER JOIN PeP_DB_06Feb2026.dbo.Employee e
        ON h.EmployeeCode = e.EmployeeCode
    GROUP BY
        e.InstanceID,
        e.BusinessUnitID
) bgv
ON bgv.InstanceID = e.InstanceID
AND bgv.BusinessUnitID = e.BusinessUnitID

GROUP BY
    e.InstanceID,
    b.BusinessUnitGroup,
    bgv.BGVCandidates

ORDER BY
    e.InstanceID,
    b.BusinessUnitGroup;
