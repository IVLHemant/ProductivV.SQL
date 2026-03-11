INSERT INTO [dbo].[BU_Summary]
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

     ISNULL(b.BusinessUnitGroup, 'Unassigned') AS BusinessUnitGroup,
    

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

    -- BGV count only under Unassigned BU
    MAX(
        CASE 
            WHEN e.BusinessUnitID IS NULL 
            THEN bgv.TotalBGV
            ELSE 0
        END
    ) AS BGVCandidates

FROM PeP_DB_06Feb2026.dbo.Employee e

LEFT JOIN PeP_DB_06Feb2026.dbo.BusinessUnitMaster b
    ON e.BusinessUnitID = b.ID
   AND e.InstanceID = b.InstanceID

LEFT JOIN PeP_DB_06Feb2026.dbo.LeaveHistory lh
    ON lh.EmployeeID = e.ID
   AND lh.InstanceID = e.InstanceID

-- Pre-aggregated BGV (single execution)
LEFT JOIN
(
    SELECT COUNT(*) AS TotalBGV
    FROM PeP_DB_06Feb2026.dbo.CandidateBGVHistory
) bgv ON 1 = 1

GROUP BY
    e.InstanceID,
    ISNULL(e.BusinessUnitID, 0),
    ISNULL(b.BusinessUnitGroup, 'Unassigned'),
    ISNULL(b.BusinessUnitDescription, 'Unassigned Business Unit')

ORDER BY
    e.InstanceID,
    ISNULL(e.BusinessUnitID, 0);
