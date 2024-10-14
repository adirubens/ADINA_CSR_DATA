
-- ===============================================================================================================================
-- Author:		Jorge Arroyo (210997) /Ruben Martinez (274494)
-- Create date: Jan 2024
-- Description:	Creates the CUSTOMER SALES REPORT DATA that goes to to the eCom site for displaying html reports for customers
-- ===============================================================================================================================

USE DB_ADI_NA_QA.SCH_ADI_NA_CORE;
SET REPORTROWS = 50;
  -- set dates
	CREATE OR REPLACE TEMPORARY TABLE	DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_DT
	(  
		DATE_KEY VARCHAR(255),
		DATE_ID INT,
	   	FY VARCHAR(5),
	   	FM VARCHAR(5),
	   	YYYY VARCHAR(4),
	   	MM VARCHAR(2)
	);
	INSERT INTO DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_DT
	SELECT  FD.DATE_KEY
			, FD.DATE_ID
			, CASE FD.YTD_FLAG WHEN -1 THEN 'PY' WHEN 1 THEN 'CY' ELSE NULL END AS FY
			, CASE FD.MTD_FLAG WHEN -1 THEN 'PYFM' WHEN 1 THEN 'CYFM' ELSE NULL END AS FM
			, DATE_FISCAL_YYYY AS YYYY
			, RIGHT(DATE_FISCAL_YYYYMM,2) AS MM
	FROM	DB_ADI_NA_QA.SCH_ADI_NA_CORE.DIM_FISCALDATES AS FD
			CROSS JOIN (SELECT DATE_ID AS LBD FROM DB_ADI_NA_QA.SCH_ADI_NA_CORE.DIM_FISCALDATES AS PY WHERE PY.DAILY_FLAG =  1) AS CY
			CROSS JOIN (SELECT DATE_ID AS LBD FROM DB_ADI_NA_QA.SCH_ADI_NA_CORE.DIM_FISCALDATES AS PY WHERE PY.DAILY_FLAG = -1) AS PY
	WHERE	YTD_FLAG IN (-1, 1)
			AND ( YTD_FLAG =  1 AND FD.DATE_ID <= CY.LBD OR YTD_FLAG = -1 AND FD.DATE_ID <= PY.LBD );
	--CREATE NONCLUSTERED INDEX D ON DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_DT(DATE_ID);
	

	-- CAT description table
	CREATE OR REPLACE TEMPORARY TABLE  DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_CATDESC 
	AS
	(
		SELECT	CAT, CAT_DESC
		FROM	DB_ADI_NA_QA.SCH_ADI_NA_CORE.Dim_CAT

	);
	
	
	-- Pull general Data
	CREATE OR REPLACE TEMPORARY TABLE DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_RAWDATA
	(
		 DATE_ID INT,
		 FY VARCHAR(5),
		 FM VARCHAR(5),
		 YYYY VARCHAR(5),
		 MM VARCHAR(2), 
	     CUSTOMER8 VARCHAR(25),
	     ORDER_NBR VARCHAR(25),
	     ORDER_TYPE_CODE VARCHAR(25),
	     CAT VARCHAR(5),
	     RCAT VARCHAR(10),
	     VENDOR_ID VARCHAR(25),
	     ITEM_ID VARCHAR(25),
	     QTY BIGINT,
	     SLS DECIMAL(12,4)
	);

	-- RAW DATA
	INSERT INTO DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_RAWDATA
	SELECT	DT.DATE_ID, DT.FY, DT.FM, DT.YYYY, DT.MM
			, CUST.SHIP_TO_ID AS CUSTOMER8 -->> CHECK IF DO I HAVE TO CHANGE THIS TO LEGACY_CUSTOMER
			, FSD.ORDER_NO AS ORDER_NBR
			, CA.ORDER_TYPE AS ORDER_TYPE_CODE
			, PG.CAT
			, PG.PRODUCT_GROUP_ID AS RCAT  -->> remember TO CHANGE this 
			, SUP.VENDOR_ID
			, FSD.ITEM_ID 
			, SUM(FSD.QTY_SHIPPED) AS QTY
			, SUM(FSD.EXTENDED_PRICE) AS SLS

	FROM	FACT_SALES AS FSD
			LEFT OUTER JOIN DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_DT AS DT
				ON FSD.INVOICE_DATE_KEY  = DT.DATE_KEY
			LEFT OUTER JOIN Dim_Customer AS CUST
				ON FSD.CUSTOMER_KEY = CUST.CUSTOMER_KEY
			LEFT OUTER JOIN Dim_Item AS ITEM
				ON FSD.ITEM_KEY  = ITEM.ITEM_KEY
			LEFT OUTER JOIN DIM_PRODUCTGROUP AS PG
				ON FSD.PRODUCT_GROUP_KEY = PG.PRODUCT_GROUP_KEY 
			LEFT OUTER JOIN DIM_CARRIER  AS CA
				ON FSD.CARRIER_KEY  = CA.CARRIER_KEY 
			LEFT OUTER JOIN DIM_SUPPLIER AS SUP
				ON FSD.SUPPLIER_KEY = SUP.SUPPLIER_KEY 
	WHERE	1 = 1 
			AND EXISTS (SELECT 1 FROM DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_DT AS FILT WHERE FSD.INVOICE_DATE_KEY = FILT.DATE_KEY)
			AND EXISTS (SELECT 1 FROM DB_ADI_GLOBAL_SBX.SCH_ADI_GLOBAL_WORKPLACE.CSR_LIST AS FILT WHERE COLLATE(CUST.LEGACY_CUSTOMER,'') = FILT.CUSTOMER)
	GROUP BY DT.DATE_ID, DT.FY, DT.FM, DT.YYYY, DT.MM
			, CUST.SHIP_TO_ID
			, FSD.ORDER_NO, CA.ORDER_TYPE
			, PG.CAT, PG.PRODUCT_GROUP_ID, SUP.VENDOR_ID, FSD.ITEM_ID;
          
			-- select top 100 * from fact_sales;
			-- select top 100 * from dim_supplier;
			-- select top 100 * from dim_item;
			-- select top 100 * from dim_invloc;
			-- select top 100 * from dim_Productgroup
			-- SELECT *  from DB_ADI_NA_DEV.SCH_ADI_NA_CORE.dim_ordersource;
			-- SELECT TOP 100 * FROM DIM_CUSTOMER
			
			-- select top 100 * from DB_ADI_P21_PROD.SCH_ADI_P21_PROD_STAGING.VW_P_OE_LINE
			-- select top 100 * from DB_ADI_NA_QA.SCH_ADI_NA_CORE.DIM_CARRIER
  			-- select top 100 * from DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_RAWDATA
			-- select top 100 * from DIM_CUSTOMER;
			
	-----------------------------------------------------------------------------------
	-- Customers data
	-----------------------------------------------------------------------------------
	-- Full customer table -- done
    CREATE OR REPLACE TEMPORARY TABLE DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_CUST
    AS   
    (
		SELECT	SHIP_TO_ID AS CUSTOMER8
		FROM	DIM_CUSTOMER AS CM 
		WHERE	EXISTS ( SELECT * FROM DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_RAWDATA AS FILT WHERE CM.SHIP_TO_ID = FILT.CUSTOMER8)
		GROUP BY SHIP_TO_ID
	);

	
	-- Get stablished date and Freight Terms
	CREATE OR REPLACE TEMPORARY TABLE DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_CM
	AS(
	SELECT	  CM.SHIP_TO_ID AS CUSTOMER -->>> AFTER COMPLETE THIS REPORT, CHANGE CUSTMER TO THE PROPER FIELD
			, CM.SHIP_TO_NAME AS CUSTNAME
			, CM.DATE_CREATED AS DATE_ESTABLISHED --> NEW FIELD ADDED
			, FC.FREIGHT_CD AS FRGHT_TRMS_CD --> ADDED 
            , FC.FREIGHT_DESC AS FRGHT_TRMS_DESC --> ADDED

	FROM	DIM_CUSTOMER AS CM
	LEFT OUTER JOIN DIM_FREIGHTCODE AS FC
		ON CM.FREIGHTCODE_KEY = FC.FREIGHTCODE_KEY
	);
    
	--------------------------------------------------------------------------------------
    -- SELECT TOP 100 * FROM DIM_FREIGHTCODE 
	-- select top 100 * from DB_ADI_NA_QA.SCH_ADI_NA_CORE.DIM_TERMS
	-- select top 100 * from DIM_CUSTOMER
	-- select top 100 * from DB_ADI_P21_PROD.SCH_ADI_P21_PROD_STAGING.VW_P_CUSTOMER
		
	-- select top 100 * from DB_ADI_NA_DEV.SCH_ADI_NA_CORE.FACT_CREDIT
	-- select top 100 * from DB_ADI_NA_PROD.SCH_ADI_NA_CORE.FACT_CUSTCREDIT
	--------------------------------------------------------------------------------------
		
		
	-- Get credit terms and status	-- NO READY

    -- Get credit terms and status - Done
	CREATE OR REPLACE TEMPORARY TABLE  DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_CS
	AS
        SELECT FC.TERMS_KEY, FC.SHIP_TO_ID AS CUSTOMER8, FCC.CREDIT_LIMIT AS CRD_LIMIT, FC.AMOUNT_PAID AS CURR_DUE -->>> CHECK IF THIS CORRESPOND TO CURR_DUE ???
        FROM FACT_CREDIT FC
        LEFT JOIN FACT_CUSTCREDIT FCC
            ON FCC.CUSTCREDIT_KEY = FC.CUSTCREDIT_KEY 
    ;
	

    -- Get last transaction -- Done
	CREATE OR REPLACE TEMPORARY TABLE DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_CLP -- ^.^
	AS (
		SELECT	CU.SHIP_TO_ID AS CUSTOMER8 --> REDIFINE NAME?
				, MAX(FD.DT) AS LAST_PURCHASED
		FROM	Fact_Sales AS FSD 
				LEFT OUTER JOIN Dim_FiscalDates AS FD 
					ON FSD.INVOICE_DATE_KEY = FD.DATE_KEY
				LEFT OUTER JOIN Dim_Customer AS CU
					ON FSD.CUSTOMER_KEY = CU.CUSTOMER_KEY
		GROUP BY CU.SHIP_TO_ID
		);

	-->>>> Table with customer's data (headers of report) -- done
	CREATE OR REPLACE TEMPORARY table DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_CUSTDATA
	AS 
	(
		SELECT	CM.CUSTOMER AS CUST
				, CM.CUSTOMER AS custnum
				, TRIM(CM.CUSTNAME) as custname
				, CM.DATE_ESTABLISHED::DATE AS established
				, LAST_PURCHASED AS lastpurchased
				, CS.CRD_LIMIT AS credit
				, CT.TERMS_DESC AS creditterms
				, CS.CURR_DUE AS pastdue
			    , CM.FRGHT_TRMS_DESC AS freightterms
		FROM	T_CM AS CM
				LEFT OUTER JOIN DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_CS AS CS 
					ON CM.CUSTOMER = CS.CUSTOMER8 -->> CHANGE TO SHIP_TO_ID
				LEFT OUTER JOIN DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_CLP AS CLP
					ON CM.CUSTOMER = CLP.CUSTOMER8
				LEFT OUTER JOIN DIM_TERMS AS CT 
					ON CS.TERMS_KEY = CT.TERMS_KEY
			WHERE	EXISTS (SELECT 1 FROM T_CUST AS FILT WHERE CM.CUSTOMER = FILT.CUSTOMER8)	
	);
	
	-- ===============================================================================
	-- Sales KPI data
	----------------------------------------------------------------------------------
	-- Define spend table:
	CREATE OR REPLACE TEMPORARY TABLE DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_SPEND (
		CUST VARCHAR(25),
		TF char(2),
		CAT varchar(5),
		CY decimal(12,2),
		PY decimal(12,2)
	);
	INSERT INTO	DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_SPEND (CUST, TF, CAT, CY, PY) -- ^.^ done
	SELECT	CUSTOMER8, 'fy' AS FY,  COALESCE(CAT, 'all') AS CAT, IFNULL(CY, 0) AS CY, IFNULL(PY, 0) AS PY
	FROM	(
				SELECT	T.FY
						, T.CAT, T.CUSTOMER8, SUM(T.SLS) AS SLS
				FROM	DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_RAWDATA AS T
				WHERE	FY IS NOT NULL			
				GROUP BY T.FY, T.CUSTOMER8, ROLLUP( T.CAT )
			)T PIVOT ( SUM(SLS) FOR FY IN ('CY', 'PY') ) AS P (CUSTOMER8, CAT, CY, PY);

    -- Get mtd data:
	INSERT INTO	T_SPEND (CUST, TF, CAT, CY, PY)
    SELECT	CUSTOMER8, 'fm' AS FM, COALESCE(CAT, 'all') AS CAT, IFNULL(CYFM, 0) AS CY, IFNULL(PYFM, 0) AS PY
	FROM	(
				SELECT	CAST(T.FM AS varchar) AS FM
						, T.CAT, T.CUSTOMER8, SUM(T.SLS) AS SLS
				FROM	DB_ADI_NA_QA.SCH_ADI_NA_CORE.T_RAWDATA AS T
				WHERE	FM IS NOT NULL --AND FM = 'CYFM'
				GROUP BY T.FM, T.CUSTOMER8, ROLLUP( T.CAT ) 
			) T PIVOT ( SUM(SLS) FOR FM IN ('CYFM','PYFM') ) as P (CUSTOMER8, CAT,CYFM, PYFM);  

    
	-----------------------------------------------------------------------------------
	-- Orders KPI data
	-----------------------------------------------------------------------------------
	-- Define table with initial date to hold each order:
	CREATE OR REPLACE TEMPORARY TABLE T_ORD0 (
		CUST VARCHAR(25),
		DATE_ID int,
		CAT	varchar(3),
		ORDER_NBR char(10)
	);

	-- Get Orders and collocation date:
	INSERT INTO T_ORD0 (CUST, CAT, DATE_ID, ORDER_NBR)
	SELECT	CUSTOMER8, 'all', MIN(DATE_ID) AS DATE_ID, ORDER_NBR
	FROM	T_RAWDATA
	WHERE	ORDER_TYPE_CODE IN ('NS', 'CC', 'QP')
	GROUP BY CUSTOMER8, ORDER_NBR;        
			
		-- Get Orders and collocation date by CAT:
	INSERT INTO	T_ORD0 (CUST, CAT, DATE_ID, ORDER_NBR)
	SELECT	CUSTOMER8, CAT, MIN(DATE_ID) AS DATE_ID, ORDER_NBR
	FROM	T_RAWDATA
	WHERE	ORDER_TYPE_CODE IN ('NS', 'CC', 'QP')
	GROUP BY CUSTOMER8, CAT, ORDER_NBR	;

    -- Get how many orders per time frame:
	CREATE OR REPLACE TEMPORARY TABLE T_ORD1 (
		CUST VARCHAR(25),
		TF char(2),
		CAT varchar(3),
		ORDERS decimal(12,1)
	);

	-- Store current year orders:
	INSERT INTO T_ORD1 (CUST, TF, CAT, ORDERS)
	SELECT	CUST, 'cy', CAT, SUM(1.0)
	FROM	T_ORD0 AS T0 
			INNER JOIN T_DT AS T1 
				ON T0.DATE_ID = T1.DATE_ID 
				AND T1.FY = 'CY'
	WHERE	CAT = 'all'
	GROUP BY CUST, CAT;

    -- Store current year orders by cat:
	INSERT INTO T_ORD1 (CUST, TF, CAT, ORDERS)
	SELECT	CUST, 'cy', CAT, SUM(1.0)
	FROM	T_ORD0 AS T0 
			INNER JOIN T_DT AS T1 
				ON T0.DATE_ID = T1.DATE_ID 
				AND T1.FY = 'CY' 
	WHERE	CAT <> 'all'
	GROUP BY CUST, CAT;

	-- Store prior year orders:
	INSERT INTO T_ORD1 (CUST, TF, CAT, ORDERS)
	SELECT	CUST, 'py', CAT, SUM(1.0)
	FROM	T_ORD0 AS T0 
			INNER JOIN T_DT AS T1 
				ON T0.DATE_ID = T1.DATE_ID 
				AND T1.FY = 'PY' 
	WHERE	CAT = 'all'
	GROUP BY CUST, CAT;

    -- Store current month orders:
	INSERT INTO T_ORD1 (CUST, TF, CAT, ORDERS)
	SELECT	CUST, 'cm', CAT, SUM(1.0)
	FROM	T_ORD0 AS T0 
			INNER JOIN T_DT AS T1 
				ON T0.DATE_ID = T1.DATE_ID 
				AND T1.FM = 'CYFM'
	WHERE	CAT = 'all'
	GROUP BY CUST, CAT;
    
    -- Store current month orders by cat:
	INSERT INTO T_ORD1 (CUST, TF, CAT, ORDERS)
	SELECT	CUST, 'cm', CAT, SUM(1.0)
	FROM	T_ORD0 AS T0 
			INNER JOIN T_DT AS T1 
				ON T0.DATE_ID = T1.DATE_ID 
				AND T1.FM = 'CYFM'
	WHERE	CAT <> 'all'
	GROUP BY CUST, CAT;

    -- Store prior yearmonth orders (all cats):
	INSERT INTO T_ORD1 (CUST, TF, CAT, ORDERS)
	SELECT	CUST, 'pm', CAT, SUM(1.0)
	FROM	T_ORD0 AS T0 
			INNER JOIN T_DT AS T1 
				ON T0.DATE_ID = T1.DATE_ID 
				AND T1.FM = 'PYFM'
	WHERE	CAT = 'all'
	GROUP BY CUST, CAT;

    -- Store prior yearmonth orders by cat:
	INSERT INTO T_ORD1 (CUST, TF, CAT, ORDERS)
	SELECT	CUST, 'pm', CAT, SUM(1.0)
	FROM	T_ORD0 AS T0 
			INNER JOIN T_DT AS T1 
				ON T0.DATE_ID = T1.DATE_ID 
				AND T1.FM = 'PYFM'
	WHERE	CAT <> 'all'
	GROUP BY CUST, CAT;

    -- Define orders table:
	CREATE OR REPLACE TEMPORARY TABLE T_ORD (
		CUST VARCHAR(10),
		TF char(2),
		CAT varchar(3),
		CY decimal(12,2),
		PY decimal(12,2)
	);

	-- Store fiscal year orders
	INSERT INTO T_ORD (CUST, TF, CAT, CY, PY)
	SELECT	CUST, 'fy' AS FY, CAT, IFNULL(CY, 0) AS CY, IFNULL(PY, 0) AS PY
	FROM	(
				SELECT	CUST, TF, CAT, ORDERS
				FROM	T_ORD1
				WHERE	TF IN ('CY', 'PY')
			) T
			PIVOT ( MAX(ORDERS) FOR TF IN ('CY', 'PY') ) AS P (CUST, CAT, CY, PY );
			
  	-- Store fiscal month orders
	INSERT INTO T_ORD (CUST, TF, CAT, CY, PY)
	SELECT	CUST, 'fm', CAT, IFNULL(CM, 0) AS CM, IFNULL(PM, 0) AS PM
	FROM	(
				SELECT	CUST, TF, CAT, ORDERS
				FROM	T_ORD1
				WHERE	TF IN ('CM', 'PM')
			) T
			PIVOT ( MAX(ORDERS) FOR TF IN ('CM', 'PM') ) AS P (CUST, CAT, CM, PM);
			
			
	
	-----------------------------------------------------------------------------------
	-- CAT colchart data
	-----------------------------------------------------------------------------------
	-- Table to hold total sales by CAT

	CREATE OR REPLACE TEMPORARY TABLE T_CAT0 (
		CUST VARCHAR(10),
		TF char(2),
		PER char(2),
		CAT varchar(3),
		SLS decimal(12,2)
	);

	-- Get YTD sales by CAT:
	INSERT INTO T_CAT0 (CUST, TF, PER, CAT, SLS)
	SELECT	CUSTOMER8, 'fy', FY, CAT, SUM(SLS) AS SLS
	FROM	T_RAWDATA
	GROUP BY CUSTOMER8, FY, CAT;

	-- Get MTD sales by CAT:
	INSERT INTO T_CAT0 (CUST, TF, PER, CAT, SLS)
	SELECT	CUSTOMER8, 'fm', LEFT(FM, 2), CAT, SUM(SLS) AS SLS
	FROM	T_RAWDATA
	WHERE	FM IS NOT NULL
	GROUP BY CUSTOMER8, LEFT(FM, 2), CAT;


	-- Hold spend by CAT by Customer:

	CREATE OR REPLACE TEMPORARY TABLE T_CAT (
		CUST VARCHAR(10),
		TF char(2),
		CAT varchar(3),
		CY decimal(12,2),
		PY decimal(12,2)
	);

	-- YTD Sales:
	INSERT INTO T_CAT (CUST, TF, CAT, CY)
	SELECT	CUST, 'fy', CAT, SLS
	FROM	(
				SELECT	CUST, CAT, SLS
				FROM	T_CAT0
				WHERE	PER = 'CY'
						AND TF = 'fy'
			)T;

	-- MTD Sales:
	INSERT INTO T_CAT (CUST, TF, CAT, CY)
	SELECT	CUST, 'fm', CAT, SLS
	FROM	(
				SELECT	CUST, CAT, SLS
				FROM	T_CAT0
				WHERE	PER = 'CY'
						AND TF = 'fm'
			)T;
		
	-->>>>>
	-- Get prior year sales of YTD

	UPDATE T_CAT
	SET PY = (
		SELECT MAX(IFNULL(S.SLS, 0))
		FROM T_CAT0 S
		WHERE T_CAT.CUST = S.CUST
		AND T_CAT.CAT = S.CAT
		AND S.TF = 'fy'
		AND S.PER = 'PY'
	)
	WHERE TF = 'fy';


	-----------------------------------------------------------------------------------
	-- RCAT barchart data
	-----------------------------------------------------------------------------------
	-- Table to hold total sales by RCAT

	CREATE OR REPLACE TEMPORARY TABLE T_RCAT0 (
		CUST varchar(10),
		TF char(2),
		PER char(2),
		CAT varchar(3),
		RCAT char(4),
		SLS decimal(12,2)
	);

	-- Get YTD sales by cat/rcat:
	INSERT INTO T_RCAT0 (CUST, TF, PER, CAT, RCAT, SLS)
	SELECT	CUSTOMER8, 'fy', FY, CAT, RCAT, SUM(SLS)
	FROM	T_RAWDATA T
	GROUP BY CUSTOMER8, FY, CAT, RCAT;

	-- Get MTD sales by cat/rcat:
	INSERT INTO T_RCAT0 (CUST, TF, PER, CAT, RCAT, SLS)
	SELECT	CUSTOMER8, 'fm', LEFT(FM, 2) , CAT, RCAT, SUM(SLS)
	FROM	T_RAWDATA T
	WHERE	FM IS NOT NULL
	GROUP BY CUSTOMER8, LEFT(FM, 2), CAT, RCAT;

	-- Hold top 10 RCAT of each CAT by customer table:
	
	CREATE OR REPLACE TEMPORARY TABLE T_RCAT (
		CUST VARCHAR(10),
		TF char(2),
		CAT varchar(3),
		RCAT char(4),
		CY decimal(12,2),
		PY decimal(12,2),
		R int
	);

	-- Get top 10 RCAT YTD sales:
	INSERT INTO T_RCAT (CUST, TF, CAT, RCAT, CY, R)
	SELECT	CUST, 'fy', CAT, RCAT, SLS, R
	FROM	(
				SELECT	CUST, 'all' AS CAT, RCAT, SLS
						, RANK() OVER(PARTITION BY CUST ORDER BY SLS DESC) AS R
				FROM	T_RCAT0
				WHERE	PER = 'CY'
						AND TF = 'fy'
			)T
	WHERE	R <= 10;

	-- Get top 10 RCAT MTD Sales:
	INSERT INTO T_RCAT (CUST, TF, CAT, RCAT, CY, R)
	SELECT	CUST, 'fm', CAT, RCAT, SLS, R
	FROM	(
				SELECT	CUST, 'all' AS CAT, RCAT, SLS
						, RANK() OVER(PARTITION BY CUST ORDER BY SLS DESC) AS R
				FROM	T_RCAT0
				WHERE	PER = 'CY'
						AND TF = 'fm'
			)T
	WHERE	R <= 10;

	-- Get top 10 RCAT YTD sales by CAT:
	INSERT INTO T_RCAT (CUST, TF, CAT, RCAT, CY, R)
	SELECT	CUST, 'fy', CAT, RCAT, SLS, R
	FROM	(
				SELECT	CUST, CAT, RCAT, SLS
						, RANK() OVER(PARTITION BY CUST, CAT ORDER BY SLS DESC) AS R
				FROM	T_RCAT0
				WHERE	PER = 'CY'
						AND TF = 'fy'
			)T
	WHERE	R <= 10;

	-- Get top 10 RCAT MTD sales:
	INSERT INTO T_RCAT (CUST, TF, CAT, RCAT, CY, R)
	SELECT	CUST, 'fm', CAT, RCAT, SLS, R
	FROM	(
				SELECT	CUST, CAT, RCAT, SLS
						, RANK() OVER(PARTITION BY CUST, CAT ORDER BY SLS DESC) AS R
				FROM	T_RCAT0
				WHERE	PER = 'CY'
						AND TF = 'fm'
			)T
	WHERE	R <= 10;

	-- Get prior Year sales of top 10 YTD
	UPDATE	T_RCAT
	SET		PY = ( SELECT MAX(IFNULL(S.SLS, 0))
				   FROM	T_RCAT0 AS S
				   WHERE T_RCAT.CUST = S.CUST
							AND T_RCAT.RCAT = S.RCAT
							AND S.TF = 'fy'
							AND S.PER = 'PY'
	)			
	WHERE TF = 'fy';

	-- Get prior Year sales of top 10 MTD
	UPDATE	T_RCAT
	SET	 PY = ( SELECT  MAX(IFNULL(S.SLS, 0))
					 FROM T_RCAT0 AS S
					 WHERE T_RCAT.CUST = S.CUST
						AND T_RCAT.RCAT = S.RCAT
						AND S.TF = 'fm'
						AND S.PER = 'PY'
					)
	WHERE	TF = 'fm';

	-----------------------------------------------------------------------------------
	-- TOP VENDORS
	-----------------------------------------------------------------------------------
	-- Table to hold top vendors by CAT
	
	CREATE OR REPLACE TEMPORARY TABLE T_VEND0 (
		CUST char(8),
		TF char(2),
		PER char(2),
		CAT varchar(3),
		VENDOR int,
		SLS decimal(12,2),
		QTY int
	);

	-- Get YTD sales by CAT/Vendor:
	INSERT INTO T_VEND0 (CUST, TF, PER, CAT, VENDOR, SLS, QTY)
	SELECT	CUSTOMER8, 'fy', FY, CAT, VENDOR_ID, SUM(SLS), SUM(QTY)
	FROM	T_RAWDATA T
	GROUP BY CUSTOMER8, FY, CAT, VENDOR_ID;

	-- Get MTD sales by CAT/Vendor:
	INSERT INTO T_VEND0 (CUST, TF, PER, CAT, VENDOR, SLS, QTY)
	SELECT	CUSTOMER8, 'fm', LEFT(FM, 2), CAT, VENDOR_ID, SUM(SLS), SUM(QTY)
	FROM	T_RAWDATA T
	WHERE	FM IS NOT NULL
	GROUP BY CUSTOMER8, LEFT(FM, 2), CAT, VENDOR_ID;

	-- Table to hold top vendors on CAT by Customer:
	CREATE OR REPLACE TEMPORARY TABLE T_VEND (
		CUST char(8),
		TF char(2),
		CAT varchar(3),
		VENDOR int,
		CY_SLS decimal(12,2),
		PY_SLS decimal(12,2),
		CY_QTY int,
		PY_QTY int,
		R int
	);

	-- Get YTD top vendors:
	INSERT INTO T_VEND (CUST, TF, CAT, VENDOR, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fy', CAT, VENDOR, SLS, QTY, R
	FROM	(
				SELECT	*, RANK() OVER(PARTITION BY CUST ORDER BY SLS DESC) AS R
				FROM	(
							SELECT	CUST, 'all' AS CAT, VENDOR, SUM(SLS) AS SLS, SUM(QTY) AS QTY					
							FROM	T_VEND0
							WHERE	PER = 'CY'
									AND TF = 'fy'
							GROUP BY CUST, VENDOR
						)T
			)T
	WHERE	R <= $REPORTROWS;

	-- Get MTD top vendors:
	INSERT INTO T_VEND (CUST, TF, CAT, VENDOR, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fm', CAT, VENDOR, SLS, QTY, R
	FROM	(
				SELECT	*, RANK() OVER(PARTITION BY CUST ORDER BY SLS DESC) AS R
				FROM	(
							SELECT	CUST, 'all' AS CAT, VENDOR, SUM(SLS) AS SLS, SUM(QTY) AS QTY					
							FROM	T_VEND0
							WHERE	PER = 'CY'
									AND TF = 'fm'
							GROUP BY CUST, VENDOR
						)T
			)T
	WHERE	R <= $REPORTROWS;

	-- Get YTD top vendors by CAT:
	INSERT INTO T_VEND (CUST, TF, CAT, VENDOR, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fy', CAT, VENDOR, SLS, QTY, R
	FROM	(
				SELECT	CUST, CAT, VENDOR, SLS, QTY
						, RANK() OVER(PARTITION BY CUST, CAT ORDER BY SLS DESC) AS R
				FROM	T_VEND0
				WHERE	PER = 'CY'
						AND TF = 'fy'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get MTD top vendors by CAT:
	INSERT INTO T_VEND (CUST, TF, CAT, VENDOR, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fm', CAT, VENDOR, SLS, QTY, R
	FROM	(
				SELECT	CUST, CAT, VENDOR, SLS, QTY
						, RANK() OVER(PARTITION BY CUST, CAT ORDER BY SLS DESC) AS R
				FROM	T_VEND0
				WHERE	PER = 'CY'
						AND TF = 'fm'
			)T
	WHERE	R <= $REPORTROWS;
 
	
	-- Get prior year sales (YTD):
	CREATE OR REPLACE TEMPORARY TABLE UpdatedValues AS (
			SELECT 
				U.CUST, 
				U.CAT, 
				U.VENDOR,
				IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
				IFNULL(S.QTY, 0) AS NEW_PY_QTY
			FROM T_VEND U
			LEFT JOIN T_VEND0 S ON U.CUST = S.CUST
								AND U.CAT = S.CAT
								AND U.VENDOR = S.VENDOR
								AND S.TF = 'fy'
								AND S.PER = 'PY'
			WHERE U.TF = 'fy'
		);
	
	MERGE INTO T_VEND AS target
	USING UpdatedValues AS source
	ON target.CUST = source.CUST 
	AND target.CAT = source.CAT 
	AND target.VENDOR = source.VENDOR
	WHEN MATCHED THEN UPDATE 
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;


	-- Get prior year sales  (MTD):

	CREATE OR REPLACE TEMPORARY TABLE UPDATEDVALUES AS (
		SELECT  U.CUST, U.CAT, U.VENDOR, IFNULL(S.SLS, 0) AS NEW_PY_SLS, IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM	T_VEND AS U
				LEFT OUTER JOIN T_VEND0 AS S
					ON U.CUST = S.CUST
					AND U.CAT = S.CAT
					AND U.VENDOR = S.VENDOR
					AND S.TF = 'fm'
					AND S.PER = 'PY'
		WHERE	U.TF = 'fm'
	);
	MERGE INTO T_VEND AS target
	USING UPDATEDVALUES AS source
	ON target.CUST = source.CUST
	AND target.CAT = source.CAT
	AND target.VENDOR = source.VENDOR
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;

	-- Get prior year sales (YTD):
	CREATE OR REPLACE TEMPORARY TABLE UPDATEDVALUES AS (
		SELECT  U.CUST, U.CAT, U.VENDOR, IFNULL(S.SLS, 0) AS NEW_PY_SLS, IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM	T_VEND AS U
				LEFT OUTER JOIN (SELECT CUST, VENDOR, TF, PER, SUM(SLS) AS SLS, SUM(QTY) AS QTY FROM T_VEND0 GROUP BY CUST, VENDOR, TF, PER) AS S
					ON U.CUST = S.CUST
					AND U.VENDOR = S.VENDOR
					AND S.TF = 'fy'
					AND S.PER = 'PY'
		WHERE	U.TF = 'fy' AND U.CAT = 'all'
	);
	MERGE INTO T_VEND AS target
	USING UPDATEDVALUES AS source
	ON target.CUST = source.CUST
	AND target.CAT = source.CAT
	AND target.VENDOR = source.VENDOR
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;


	-- Get prior year sales (MTD):
  	CREATE OR REPLACE TEMPORARY TABLE UPDATEDVALUES AS (
		SELECT  U.CUST, U.CAT, U.VENDOR, IFNULL(S.SLS, 0) AS NEW_PY_SLS, IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM	T_VEND AS U
				LEFT OUTER JOIN (SELECT CUST, VENDOR, TF, PER, SUM(SLS) AS SLS, SUM(QTY) AS QTY FROM T_VEND0 GROUP BY CUST, VENDOR, TF, PER) AS S
					ON U.CUST = S.CUST
					AND U.VENDOR = S.VENDOR
					AND S.TF = 'fm'
					AND S.PER = 'PY'
		WHERE	U.TF = 'fm' AND U.CAT = 'all'
	);
	MERGE INTO T_VEND AS target
	USING UPDATEDVALUES AS source
	ON target.CUST = source.CUST
	AND target.CAT = source.CAT
	AND target.VENDOR = source.VENDOR
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;
    
    -----------------------------------------------------------------------------------
	-- Top sold items data by sales
	-----------------------------------------------------------------------------------
	-- Table to hold top items/dollars by CAT + ALL

	CREATE OR REPLACE TEMPORARY TABLE T_ITEM0 (
		CUST VARCHAR(10),
		TF char(2),
		PER char(2),
		CAT varchar(3),
		ITEM VARCHAR(25),
		SLS decimal(12,2),
		QTY int
	);

	-- Get YTD sales:
	INSERT INTO T_ITEM0 (CUST, TF, PER, CAT, ITEM, SLS, QTY)
	SELECT	CUSTOMER8, 'fy', FY, CAT, ITEM_ID, SUM(SLS), SUM(QTY)
	FROM	T_RAWDATA T
	GROUP BY CUSTOMER8, FY, CAT, ITEM_ID;

	-- Get MTD sales:
	INSERT INTO T_ITEM0 (CUST, TF, PER, CAT, ITEM, SLS, QTY)
	SELECT	CUSTOMER8, 'fm', LEFT(FM, 2), CAT, ITEM_ID, SUM(SLS), SUM(QTY)
	FROM	T_RAWDATA T
	WHERE	FM IS NOT NULL
	GROUP BY CUSTOMER8, LEFT(FM, 2), CAT, ITEM_ID;

	-- Hold top items/dollars on CAT by Customer:

	CREATE OR REPLACE TEMPORARY TABLE T_ITEMSLS (
		CUST char(8),
		TF char(2),
		CAT varchar(3),
		ITEM VARCHAR(25),
		CY_SLS decimal(12,2),
		PY_SLS decimal(12,2),
		CY_QTY int,
		PY_QTY int,
		R int
	);

	-- Get top YTD items by sales:
	INSERT INTO T_ITEMSLS (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fy', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, 'all' AS CAT, ITEM, SLS, QTY 
						, RANK() OVER(PARTITION BY CUST ORDER BY SLS DESC) AS R
				FROM	T_ITEM0
				WHERE	PER = 'CY'
						AND TF = 'fy'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get top MTD items by sales:
	INSERT INTO T_ITEMSLS (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fm', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, 'all' AS CAT, ITEM, SLS, QTY
						, RANK() OVER(PARTITION BY CUST ORDER BY SLS DESC) AS R
				FROM	T_ITEM0
				WHERE	PER = 'CY'
						AND TF = 'fm'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get top YTD items by sales by CAT:
	INSERT INTO T_ITEMSLS (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fy', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, CAT, ITEM, SLS, QTY
						, RANK() OVER(PARTITION BY CUST, CAT ORDER BY SLS DESC) AS R
				FROM	T_ITEM0
				WHERE	PER = 'CY'
						AND TF = 'fy'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get top MTD items by sales by CAT:
	INSERT INTO T_ITEMSLS (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fm', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, CAT, ITEM, SLS, QTY
						, RANK() OVER(PARTITION BY CUST, CAT ORDER BY SLS DESC) AS R
				FROM	T_ITEM0
				WHERE	PER = 'CY'
						AND TF = 'fm'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get prior year sales of YTD items:
	/*
	UPDATE	U
	SET		U.PY_SLS = IFNULL(S.SLS, 0)
			, U.PY_QTY = IFNULL(S.QTY, 0)
	FROM	T_ITEMSLS AS U
			LEFT OUTER JOIN T_ITEM0 AS S
				ON U.CUST = S.CUST
				AND U.CAT = S.CAT
				AND U.ITEM = S.ITEM
				AND S.TF = 'fy'
				AND S.PER = 'PY'
	WHERE	U.TF = 'fy' AND U.CAT <> 'all';
	*/

	CREATE OR REPLACE TEMPORARY TABLE UpdatedValues AS (
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_ITEMSLS U
		LEFT JOIN T_ITEM0 S ON U.CUST = S.CUST
							AND U.CAT = S.CAT
							AND U.ITEM = S.ITEM
							AND S.TF = 'fy'
							AND S.PER = 'PY'
		WHERE U.TF = 'fy' AND U.CAT <> 'all'
	);
	MERGE INTO T_ITEMSLS AS target										
	USING UpdatedValues AS source
	ON target.CUST = source.CUST
	AND target.CAT = source.CAT
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;

	-- Get prior year sales of MTD items:
	/*
	UPDATE	U
	SET		U.PY_SLS = IFNULL(S.SLS, 0)
			, U.PY_QTY = IFNULL(S.QTY, 0)
	FROM	T_ITEMSLS AS U
			LEFT OUTER JOIN T_ITEM0 AS S
				ON U.CUST = S.CUST
				AND U.CAT = S.CAT
				AND U.ITEM = S.ITEM
				AND S.TF = 'fm'
				AND S.PER = 'PY'
	WHERE	U.TF = 'fm' AND U.CAT <> 'all'; */
	-- Get prior year sales of MTD items:
	CREATE OR REPLACE TEMPORARY TABLE UpdatedValues AS (
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_ITEMSLS U
		LEFT JOIN T_ITEM0 S ON U.CUST = S.CUST
							AND U.CAT = S.CAT
							AND U.ITEM = S.ITEM
							AND S.TF = 'fm'
							AND S.PER = 'PY'
		WHERE U.TF = 'fm' AND U.CAT <> 'all'
	);
	MERGE INTO T_ITEMSLS AS target	
	USING UpdatedValues AS source
	ON target.CUST = source.CUST
	AND target.CAT = source.CAT
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;


	-- Get prior year sales of MTD items by CAT:
	/*
	UPDATE	U
	SET		U.PY_SLS = IFNULL(S.SLS, 0), U.PY_QTY = IFNULL(S.QTY, 0)
	FROM	T_ITEMSLS AS U
			LEFT OUTER JOIN (SELECT CUST, ITEM, TF, PER, SUM(SLS) SLS, SUM(QTY) QTY FROM T_ITEM0 GROUP BY CUST, ITEM, TF, PER) AS S
				ON U.CUST = S.CUST
				AND U.ITEM = S.ITEM
				AND S.TF = 'fy'
				AND S.PER = 'PY'
	WHERE	U.TF = 'fy' AND U.CAT = 'all';
	*/
	CREATE OR REPLACE TEMPORARY TABLE UpdatedValues AS (
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_ITEMSLS U
		LEFT JOIN (SELECT CUST, ITEM, TF, PER, SUM(SLS) SLS, SUM(QTY) QTY FROM T_ITEM0 GROUP BY CUST, ITEM, TF, PER) AS S
			 ON U.CUST = S.CUST
							AND U.ITEM = S.ITEM
							AND S.TF = 'fy'
							AND S.PER = 'PY'
		WHERE U.TF = 'fy' AND U.CAT = 'all'
	);

	MERGE INTO T_ITEMSLS AS target
	USING UpdatedValues AS source
	ON target.CUST = source.CUST
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;


	-- Get prior year sales of YTD items by CAT:
	/*
	UPDATE	U
	SET		U.PY_SLS = IFNULL(S.SLS, 0), U.PY_QTY = IFNULL(S.QTY, 0)
	FROM	T_ITEMSLS AS U
			LEFT OUTER JOIN (SELECT CUST, ITEM, TF, PER, SUM(SLS) SLS, SUM(QTY) QTY FROM T_ITEM0 GROUP BY CUST, ITEM, TF, PER) AS S
				ON U.CUST = S.CUST
				AND U.ITEM = S.ITEM
				AND S.TF = 'fm'
				AND S.PER = 'PY'
	WHERE	U.TF = 'fm' AND U.CAT = 'all';
	*/
	CREATE OR REPLACE TEMPORARY TABLE UpdatedValues AS (
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_ITEMSLS U
		LEFT JOIN (SELECT CUST, ITEM, TF, PER, SUM(SLS) SLS, SUM(QTY) QTY FROM T_ITEM0 GROUP BY CUST, ITEM, TF, PER) AS S 
			ON U.CUST = S.CUST
							AND U.ITEM = S.ITEM
							AND S.TF = 'fm'
							AND S.PER = 'PY'
		WHERE U.TF = 'fm' AND U.CAT = 'all'
	);

	MERGE INTO T_ITEMSLS AS target
	USING UpdatedValues AS source
	ON target.CUST = source.CUST
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;


	-----------------------------------------------------------------------------------
	-- Top sold items data by quantities
	-----------------------------------------------------------------------------------
	-- Table to Hold top items/qty on CAT by Customer:
	
	CREATE OR REPLACE TEMPORARY TABLE T_ITEMQTY (
		CUST varchar(10),
		TF char(2),
		CAT varchar(3),
		ITEM varchar(25),
		CY_SLS decimal(12,2),
		PY_SLS decimal(12,2),
		CY_QTY int,
		PY_QTY int,
		R int
	);

	-- Get top items YTD by quantity sold:
	INSERT INTO T_ITEMQTY (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fy', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, 'all' AS CAT, ITEM, SLS, QTY
						, RANK() OVER(PARTITION BY CUST ORDER BY QTY DESC) AS R
				FROM	T_ITEM0
				WHERE	PER = 'CY'
						AND TF = 'fy'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get top items MTD by quantity sold:
	INSERT INTO T_ITEMQTY (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fm', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, 'all' AS CAT, ITEM, SLS, QTY
						, RANK() OVER(PARTITION BY CUST ORDER BY QTY DESC) AS R
				FROM	T_ITEM0
				WHERE	PER = 'CY'
						AND TF = 'fm'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get top items YTD by quantity sold by CAT:
	INSERT INTO T_ITEMQTY (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fy', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, CAT, ITEM, SLS, QTY
						, RANK() OVER(PARTITION BY CUST, CAT ORDER BY QTY DESC) AS R
				FROM	T_ITEM0
				WHERE	PER = 'CY'
						AND TF = 'fy'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get top items MTD by quantity sold by CAT:
	INSERT INTO T_ITEMQTY (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fm', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, CAT, ITEM, SLS, QTY
						, RANK() OVER(PARTITION BY CUST, CAT ORDER BY QTY DESC) AS R
				FROM	T_ITEM0
				WHERE	PER = 'CY'
						AND TF = 'fm'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get prior Year sales of YTD

	CREATE OR REPLACE TEMPORARY TABLE UPDATEDVALUES AS(
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_ITEMQTY U
		LEFT JOIN (SELECT CUST, ITEM, TF, PER, SUM(SLS) AS SLS, SUM(QTY) AS QTY FROM T_ITEM0 GROUP BY CUST, ITEM, TF, PER) AS S
		ON U.CUST = S.CUST
							
							AND U.ITEM = S.ITEM
							AND S.TF = 'fy'
							AND S.PER = 'PY'
		WHERE U.TF = 'fy' AND U.CAT <> 'all'
	);
	MERGE INTO T_ITEMQTY AS target
	USING UPDATEDVALUES AS source
	ON target.CUST = source.CUST
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;

	-- Get prior Year sales of MTD
	CREATE OR REPLACE TEMPORARY TABLE UPDATEDVALUES AS(
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_ITEMQTY U
		LEFT JOIN (SELECT CUST, ITEM, TF, PER, SUM(SLS) AS SLS, SUM(QTY) AS QTY FROM T_ITEM0 GROUP BY CUST, ITEM, TF, PER) AS S
		ON U.CUST = S.CUST
							
							AND U.ITEM = S.ITEM
							AND S.TF = 'fm'
							AND S.PER = 'PY'
		WHERE U.TF = 'fm' AND U.CAT <> 'all'
	);
	MERGE INTO T_ITEMQTY AS target
	USING UPDATEDVALUES AS source
	ON target.CUST = source.CUST
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;

	-- Get prior Year sales of YTD by CAT	
	CREATE OR REPLACE TEMPORARY TABLE UPDATEDVALUES AS(
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_ITEMQTY U
		LEFT JOIN T_ITEM0 S ON U.CUST = S.CUST
							AND U.ITEM = S.ITEM
							AND U.cat = S.cat
							AND S.TF = 'fy'
							AND S.PER = 'PY'
		WHERE U.TF = 'fy' AND U.CAT <> 'all'
	);
	MERGE INTO T_ITEMQTY AS target
	USING UPDATEDVALUES AS source
	ON target.CUST = source.CUST
	AND target.CAT = source.CAT
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;

	-- Get prior Year sales of MTD by CAT
	CREATE OR REPLACE TEMPORARY TABLE UPDATEDVALUES AS(
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_ITEMQTY U
		LEFT JOIN T_ITEM0 S ON U.CUST = S.CUST
							AND U.ITEM = S.ITEM
							AND U.cat = S.cat
							AND S.TF = 'fm'
							AND S.PER = 'PY'
		WHERE U.TF = 'fm' AND U.CAT <> 'all'
	);

	MERGE INTO T_ITEMQTY AS target
	USING UPDATEDVALUES AS source
	ON target.CUST = source.CUST
	AND target.CAT = source.CAT
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;

	-----------------------------------------------------------------------------------
	-- Top returns items data
	-----------------------------------------------------------------------------------
	-- Table to hold top returns:
	
	CREATE OR REPLACE TEMPORARY TABLE T_RETU0 (
		CUST char(8),
		TF char(2),
		PER char(2),
		CAT varchar(3),
		ITEM VARCHAR(25),
		SLS decimal(12,2),
		QTY int
	);

	-- Get YTD returns:
	INSERT INTO T_RETU0 (CUST, TF, PER, CAT, ITEM, SLS, QTY)
	SELECT	CUSTOMER8, 'fy', FY, CAT, ITEM_ID, SUM(SLS), SUM(QTY)
	FROM	T_RAWDATA T
	WHERE	ORDER_TYPE_CODE NOT IN ('CC', 'QP', 'NS', 'DC')
	GROUP BY CUSTOMER8, FY, CAT, ITEM_ID;

	-- Get MTD returns:
	INSERT INTO T_RETU0 (CUST, TF, PER, CAT, ITEM, SLS, QTY)
	SELECT	CUSTOMER8, 'fm', LEFT(FM, 2), CAT, ITEM_ID, SUM(SLS), SUM(QTY)
	FROM	T_RAWDATA T
	WHERE	FM IS NOT NULL
			AND	ORDER_TYPE_CODE NOT IN ('CC', 'QP', 'NS', 'DC')
	GROUP BY CUSTOMER8, LEFT(FM, 2), CAT, ITEM_ID;

	-- Table to Hold top returned items by customer:
	
	CREATE OR REPLACE TEMPORARY TABLE T_RETURNS (
		CUST char(8),
		TF char(2),
		CAT varchar(3),
		ITEM VARCHAR(25),
		CY_SLS decimal(12,2),
		PY_SLS decimal(12,2),
		CY_QTY int,
		PY_QTY int,
		R int
	);

	-- Get top YTD returns:
	INSERT INTO T_RETURNS (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fy', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, 'all' AS CAT, ITEM, SLS, QTY
						, RANK() OVER(PARTITION BY CUST ORDER BY SLS ASC) AS R
				FROM	T_RETU0
				WHERE	PER = 'CY'
						AND TF = 'fy'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get top MTD returns:
	INSERT INTO T_RETURNS (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fm', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, 'all' AS CAT, ITEM, SLS, QTY
						, RANK() OVER(PARTITION BY CUST ORDER BY SLS ASC) AS R
				FROM	T_RETU0
				WHERE	PER = 'CY'
						AND TF = 'fm'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get top YTD returns by CAT:
	INSERT INTO T_RETURNS (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fy', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, CAT, ITEM, SLS, QTY
						, RANK() OVER(PARTITION BY CUST, CAT ORDER BY SLS ASC) AS R
				FROM	T_RETU0
				WHERE	PER = 'CY'
						AND TF = 'fy'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get top MTD returns by CAT:
	INSERT INTO T_RETURNS (CUST, TF, CAT, ITEM, CY_SLS, CY_QTY, R)
	SELECT	CUST, 'fm', CAT, ITEM, SLS, QTY, R
	FROM	(
				SELECT	CUST, CAT, ITEM, SLS, QTY
						, RANK() OVER(PARTITION BY CUST, CAT ORDER BY SLS ASC) AS R
				FROM	T_RETU0
				WHERE	PER = 'CY'
						AND TF = 'fm'
			)T
	WHERE	R <= $REPORTROWS;

	-- Get prior year returns for YTD data
	/*
	UPDATE	U
	SET		U.PY_SLS = IFNULL(S.SLS, 0), U.PY_QTY = IFNULL(S.QTY, 0)
	FROM	T_RETURNS AS U
			LEFT OUTER JOIN (SELECT CUST, ITEM, TF, PER, SUM(SLS) SLS, SUM(QTY) QTY FROM T_RETU0 GROUP BY CUST, ITEM, TF, PER) AS S
				ON U.CUST = S.CUST
				AND U.ITEM = S.ITEM
				AND S.TF = 'fy'
				AND S.PER = 'PY'
	WHERE	U.TF = 'fy' AND U.CAT = 'all';
  	*/
	CREATE OR REPLACE TEMPORARY TABLE UpdatedValues AS (
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_RETURNS U
		LEFT JOIN (SELECT CUST, ITEM, TF, PER, SUM(SLS) SLS, SUM(QTY) QTY FROM T_RETU0 GROUP BY CUST, ITEM, TF, PER) AS S
		 ON U.CUST = S.CUST
							AND U.ITEM = S.ITEM
							AND S.TF = 'fy'
							AND S.PER = 'PY'
		WHERE U.TF = 'fy' AND U.CAT <> 'all'
	);
	MERGE INTO T_RETURNS AS target
	USING UpdatedValues AS source
	ON target.CUST = source.CUST
	AND target.CAT = source.CAT
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;

	-- Get prior year returns for MTD data
	/*
	UPDATE	U
	SET		U.PY_SLS = IFNULL(S.SLS, 0), U.PY_QTY = IFNULL(S.QTY, 0)
	FROM	T_RETURNS AS U
			LEFT OUTER JOIN (SELECT CUST, ITEM, TF, PER, SUM(SLS) SLS, SUM(QTY) QTY FROM T_RETU0 GROUP BY CUST, ITEM, TF, PER) AS S
				ON U.CUST = S.CUST
				AND U.ITEM = S.ITEM
				AND S.TF = 'fm'
				AND S.PER = 'PY'
	WHERE	U.TF = 'fm' AND U.CAT = 'all';
	*/
	CREATE OR REPLACE TEMPORARY TABLE UpdatedValues AS (
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_RETURNS U
		LEFT JOIN (SELECT CUST, ITEM, TF, PER, SUM(SLS) SLS, SUM(QTY) QTY FROM T_RETU0 GROUP BY CUST, ITEM, TF, PER) AS S
		 ON U.CUST = S.CUST						
							AND U.ITEM = S.ITEM
							AND S.TF = 'fm'
							AND S.PER = 'PY'
		WHERE U.TF = 'fm' AND U.CAT <> 'all'
	);
	MERGE INTO T_RETURNS AS target
	USING UpdatedValues AS source
	ON target.CUST = source.CUST
	AND target.CAT = source.CAT
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;

	-- Get prior year returns for YTD data by CAT
	/*
	UPDATE	U
	SET		U.PY_SLS = IFNULL(S.SLS, 0), U.PY_QTY = IFNULL(S.QTY, 0)
	FROM	T_RETURNS AS U
			LEFT OUTER JOIN T_RETU0 AS S
				ON U.CUST = S.CUST
				AND U.CAT = S.CAT
				AND U.ITEM = S.ITEM
				AND S.TF = 'fy'
				AND S.PER = 'PY'
	WHERE	U.TF = 'fy' AND U.CAT <> 'all';
  */

	CREATE OR REPLACE TEMPORARY TABLE UpdatedValues AS (
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_RETURNS U
		LEFT JOIN T_RETU0 S ON U.CUST = S.CUST
							AND U.CAT = S.CAT
							AND U.ITEM = S.ITEM
							AND S.TF = 'fy'
							AND S.PER = 'PY'
		WHERE U.TF = 'fy' AND U.CAT <> 'all'
	);
	MERGE INTO T_RETURNS AS target
	USING UpdatedValues AS source
	ON target.CUST = source.CUST
	AND target.CAT = source.CAT
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;

	-- Get prior year returns for MTD data by CAT
	/*
	UPDATE	U
	SET		U.PY_SLS = IFNULL(S.SLS, 0), U.PY_QTY = IFNULL(S.QTY, 0)
	FROM	T_RETURNS AS U
			LEFT OUTER JOIN T_RETU0 AS S
				ON U.CUST = S.CUST
				AND U.CAT = S.CAT
				AND U.ITEM = S.ITEM
				AND S.TF = 'fm'
				AND S.PER = 'PY'
	WHERE	U.TF = 'fm' AND U.CAT <> 'all';
    */
	CREATE OR REPLACE TEMPORARY TABLE UpdatedValues AS (
		SELECT 
			U.CUST, 
			U.CAT, 
			U.ITEM,
			IFNULL(S.SLS, 0) AS NEW_PY_SLS, 
			IFNULL(S.QTY, 0) AS NEW_PY_QTY
		FROM T_RETURNS U
		LEFT JOIN T_RETU0 S ON U.CUST = S.CUST
							AND U.CAT = S.CAT
							AND U.ITEM = S.ITEM
							AND S.TF = 'fm'
							AND S.PER = 'PY'
		WHERE U.TF = 'fm' AND U.CAT <> 'all'
	);
	MERGE INTO T_RETURNS AS target
	USING UpdatedValues AS source
	ON target.CUST = source.CUST
	AND target.CAT = source.CAT
	AND target.ITEM = source.ITEM
	WHEN MATCHED THEN UPDATE
	SET target.PY_SLS = source.NEW_PY_SLS,
		target.PY_QTY = source.NEW_PY_QTY;



	-----------------------------------------------------------------------------------
	-- Open Quotes Data
	-----------------------------------------------------------------------------------
	-- Table to hold quotes raw data:

	CREATE OR REPLACE TEMPORARY TABLE QT0 (
		CUST varchar(10),
		FY char(2),
		FM char(2),
		DT date,
		CITY varchar(40),
		ST varchar(5),
		ORDER_NBR varchar(10),
		EMP_NAME varchar(40),
		ORDER_AMT decimal(12,2)
	);

	--->>>>> Pending
	-- Get historical quotes data:
 
		-- REMOVE SUFFIX
	INSERT INTO QT0
	SELECT	FO.CUSTOMER_ID AS CUST, FY, LEFT(FM, 2) FM, FD.DT, LO.CITY, LO.ST, FO.ORDER_NO AS ORDER_NBR, PID.EMP_NAME, QTY_ORDERED AS ORDER_AMT
	FROM	FACT_ORDERS AS FO
			LEFT OUTER JOIN Dim_FiscalDates AS FD 
				ON FO.ORDER_DATE_KEY = FD.DATE_KEY
			LEFT OUTER JOIN Dim_Customer AS CU 
				ON FO.CUSTOMER_KEY = CU.CUSTOMER_KEY
			LEFT OUTER JOIN Dim_LOCATION AS LO
				ON FO.LOCATION_KEY = LO.LOCATION_KEY
			LEFT OUTER JOIN Dim_PID AS PID
				ON PID.PID_KEY = FO.PID_KEY
			LEFT OUTER JOIN T_DT AS DT 
				ON FD.DATE_ID = DT.DATE_ID
	WHERE	TRUE 
	        AND FO.QUOTE_FLAG= 'N' 
			AND FO.PROJECT_QUOTE_FLAG = '0' -- change to a boolean value
	GROUP BY ALL;

	
	-- Get daily quotes data:
	INSERT INTO QT0
	SELECT	FO.CUSTOMER_ID AS CUST, FY, LEFT(FM, 2) FM, FD.DT, LO.CITY, LO.ST, FO.ORDER_NO AS ORDER_NBR, PID.EMP_NAME, QTY_ORDERED AS ORDER_AMT
	FROM	FACT_ORDERS AS FO
			LEFT OUTER JOIN Dim_FiscalDates AS FD 
				ON FO.ORDER_DATE_KEY = FD.DATE_KEY
			LEFT OUTER JOIN Dim_Customer AS CU 
				ON FO.CUSTOMER_KEY = CU.CUSTOMER_KEY
			LEFT OUTER JOIN Dim_LOCATION AS LO
				ON FO.LOCATION_KEY = LO.LOCATION_KEY
			LEFT OUTER JOIN Dim_PID AS PID
				ON PID.PID_KEY = FO.PID_KEY
			LEFT OUTER JOIN T_DT AS DT 
				ON FD.DATE_ID = DT.DATE_ID
	WHERE	TRUE 
	        AND FO.QUOTE_FLAG= 'N' 
			AND FO.PROJECT_QUOTE_FLAG = '1' -- change to a boolean value
	GROUP BY ALL;

	-- Table with quotes data:
	
	CREATE OR REPLACE TEMPORARY TABLE T_QUOTES (
		CUST varchar(10),
		TF char(2),
		DT date,
		CITY varchar(40),
		ST varchar(5),
		ORDER_NBR varchar(10),
		EMP_NAME varchar(40),
		ORDER_AMT decimal(12,2)
	);

	-- Get FM quotes data:
	INSERT INTO T_QUOTES
	SELECT	DISTINCT
			CUST, 'fm' TF, DT, CITY, ST, ORDER_NBR, EMP_NAME, ORDER_AMT
	FROM	QT0
	WHERE	FM = 'CY';

	-- Get FY quotes data:
	INSERT INTO T_QUOTES
	SELECT DISTINCT
			CUST, 'fy' TF, DT, CITY, ST, ORDER_NBR, EMP_NAME, ORDER_AMT
	FROM	QT0
	WHERE	FY = 'CY';



	-----------------------------------------------------------------------------------
	-- OPEN PROJECTS  ***** PENDING TO DO ***** HOW PROJECTS WORKS IN P21????
	-----------------------------------------------------------------------------------
	-- Table to hold projects raw data:
	
	CREATE OR REPLACE TEMPORARY TABLE T_PR0 (
		CUST char(8),
		FY char(2),
		FM char(2),
		DT date,
		CITY varchar(40),
		ST varchar(5),
		ORDER_NO varchar(10),
		EMP_NAME varchar(40),
		ORDER_AMT decimal(12,2)
	);

	------->>>>>>>>>>>>>>>>>>>>>>> *** Get historical projects: CREATE A NEW TABLE FOR PROJECTS
	INSERT INTO T_PR0
	SELECT	CU.SHIP_TO_ID AS CUST, FY, LEFT(FM, 2) FM, FD.DT, LO.CITY, LO.ST, FO.ORDER_NO AS ORDER_NBR, PID.EMP_NAME, QTY_ORDERED AS ORDER_AMT
	FROM	FACT_ORDERS AS FO
	--FROM	SHOWCASE.DATAWHSE.QUOTE_TRACKING AS QT
			LEFT OUTER JOIN Dim_FiscalDates AS FD 
				ON FO.ORDER_DATE_KEY = FD.DATE_KEY
			LEFT OUTER JOIN Dim_Customer AS CU 
				ON FO.CUSTOMER_KEY = CU.CUSTOMER_KEY
			LEFT OUTER JOIN Dim_LOCATION AS LO
				ON CU.LOCATION_KEY = LO.LOCATION_KEY
			LEFT OUTER JOIN Dim_PID AS PID
				ON PID.PID_KEY = FO.PID_KEY
			LEFT OUTER JOIN T_DT AS DT 
				ON FD.DATE_ID = DT.DATE_ID
	WHERE	FO.QUOTE_FLAG = 'N'
			AND FO.PROJECT_QUOTE_FLAG= 1
	GROUP BY ALL;

	
	-- Get daily projects:
	INSERT INTO T_PR0
	SELECT	FO.CUSTOMER_ID AS CUST, FY, LEFT(FM, 2) FM, FD.DT, LO.CITY, LO.ST, FO.ORDER_NO AS ORDER_NBR, PID.EMP_NAME, QTY_ORDERED AS ORDER_AMT
	FROM	FACT_ORDERS AS FO
			LEFT OUTER JOIN Dim_FiscalDates AS FD 
				ON FO.ORDER_DATE_KEY = FD.DATE_KEY
			LEFT OUTER JOIN Dim_Customer AS CU 
				ON FO.CUSTOMER_KEY = CU.CUSTOMER_KEY
			LEFT OUTER JOIN Dim_LOCATION AS LO
				ON FO.LOCATION_KEY = LO.LOCATION_KEY
			LEFT OUTER JOIN Dim_PID AS PID
				ON PID.PID_KEY = FO.PID_KEY
			LEFT OUTER JOIN T_DT AS DT 
				ON FD.DATE_ID = DT.DATE_ID
	WHERE	TRUE 
	        AND FO.QUOTE_FLAG= 'N' 
			AND FO.PROJECT_QUOTE_FLAG = '1' -- change to a boolean value
	GROUP BY ALL;

	-- Table to hold projects:
	
	CREATE OR REPLACE TEMPORARY TABLE T_PROJECTS (
		CUST char(8),
		TF char(2),
		DT date,
		CITY varchar(40),
		ST varchar(5),
		ORDER_NO varchar(10),
		EMP_NAME varchar(40),
		ORDER_AMT decimal(12,2)
	);

	-- Get FM projects data:
	INSERT INTO T_PROJECTS
	SELECT	DISTINCT
			CUST, 'fm' TF, DT,  CITY, ST, ORDER_NO, EMP_NAME, ORDER_AMT
	FROM	T_PR0
	WHERE	FM = 'CY';

	-- Get FY projects data:
	INSERT INTO T_PROJECTS
	SELECT	DISTINCT
			CUST, 'fy' TF, DT, CITY, ST, ORDER_NO, EMP_NAME, ORDER_AMT
	FROM	T_PR0
	WHERE	FY = 'CY' ;
	


	
	-----------------------------------------------------------------------------------
	-- Trend Chart
	-----------------------------------------------------------------------------------
	-- Cross table of Fiscal Months and CATs:
	CREATE OR REPLACE TABLE DT_YTD (
		   DATE_ID int,
		   MM varchar(2),
		   CAT varchar(3)
	);
	INSERT INTO   DT_YTD
	SELECT CONCAT(YYYY, MM, '01') AS DATE_ID, MM, CAT
	FROM   T_DT
				  CROSS JOIN (SELECT CAT FROM T_CATDESC UNION SELECT 'all') T
	WHERE  FY = 'CY'
	GROUP BY CONCAT(YYYY, MM, '01'), MM, CAT;

	-- Cross table of days of the month and CATs:
	CREATE OR REPLACE TEMPORARY TABLE DT_MTD (
		   DATE_ID int,
		   DATE_ID_PY int,
		   DT date,
		   CAT varchar(3)
	);
	
	INSERT INTO DT_MTD
	SELECT DT.DATE_ID, VS.DATE_ID_PY, FD.DT, CAT
	FROM   T_DT DT
				  LEFT OUTER JOIN Dim_FiscalDates FD ON DT.DATE_ID = FD.DATE_ID
				  LEFT OUTER JOIN DB_ADI_GLOBAL_SBX.SCH_ADI_GLOBAL_CORE.VW_FISCAL_CY_VS_PY VS ON FD.DATE_ID = VS.DATE_ID
				  CROSS JOIN (SELECT CAT FROM T_CATDESC UNION SELECT 'all') T
	WHERE  FM = 'CYFM'
				  AND FD.WK_NUM BETWEEN 2 AND 6 AND CAT <> '0';
	-- Table to hold sales by dates and cats:
	CREATE OR REPLACE TEMPORARY TABLE TC_MTD0 (
		   CUST char(8),
		   DATE_ID int,
		   CAT varchar(3),
		   SLS decimal(12,2)
	);

	-- Get all daily sales by CAT and all:
	INSERT INTO TC_MTD0
	SELECT T.CUSTOMER8, T.DATE_ID, COALESCE(T.CAT, 'all') CAT, SUM(T.SLS) AS SLS
	FROM   T_RAWDATA AS T
	WHERE  FM IS NOT NULL
	GROUP BY T.DATE_ID, T.CUSTOMER8, ROLLUP( T.CAT );

	-- Table to hold sales by Fiscal Months:
	
	CREATE OR REPLACE TEMPORARY TABLE TC_YTD0 (
		   CUST varchar(10),
		   DATE_ID int,
		   MM varchar(2),
		   FY varchar(2),
		   CAT varchar(3),
		   SLS decimal(12,2)
	);

	-- Get Sales by Fiscal Months:
	INSERT INTO TC_YTD0
	SELECT T.CUSTOMER8, D.DATE_ID, D.MM, FY, COALESCE(T.CAT, 'all') CAT, SUM(T.SLS) AS SLS
	FROM   T_RAWDATA AS T
				  LEFT OUTER JOIN (SELECT DISTINCT DATE_ID, MM FROM DT_YTD) AS D ON T.MM = D.MM
	GROUP BY D.DATE_ID, D.MM, FY, T.CUSTOMER8, ROLLUP( T.CAT );

	-- Table to hold monthly sales:

	CREATE OR REPLACE TEMPORARY TABLE TC_MTD (
		   CUST char(8),
		   DATE_ID int,
		   CAT varchar(3),
		   CY decimal(12,2),
		   PY decimal(12,2)
	);

	-- Get base of all sales:
	CREATE OR REPLACE TEMPORARY TABLE BASE_MTD (
		  
	       DATE_ID int,
		   DATE_ID_PY int,
		   DT date,
		   CAT varchar(3),
            CUSTOMER8 varchar(8)
		   );
    INSERT INTO BASE_MTD
    SELECT * FROM DT_MTD D CROSS JOIN T_CUST C;

    CREATE OR REPLACE TEMPORARY TABLE TC_MTD (
           CUST varchar(10),
           DATE_ID int,
           CAT varchar(3),
           CY decimal(12,2),
           PY decimal(12,2)
    );

	INSERT INTO TC_MTD
	SELECT	DT.CUSTOMER8, DT.DATE_ID, DT.CAT, SUM(IFF(DT.DATE_ID = TC.DATE_ID, SLS, 0)) CY, SUM(IFF(DT.DATE_ID_PY = TC.DATE_ID, SLS, 0)) PY
	FROM	BASE_MTD DT
			LEFT OUTER JOIN TC_MTD0 TC 
				ON (DT.DATE_ID = TC.DATE_ID OR DT.DATE_ID_PY = TC.DATE_ID) 
				AND DT.CAT = TC.CAT 
				AND DT.CUSTOMER8 = TC.CUST
	GROUP BY DT.DATE_ID, DT.CAT, DT.CUSTOMER8;

	-- Get YTD sales:
	CREATE OR REPLACE TEMPORARY TABLE BASE_YTD (
		   
		   DATE_ID int,
		   MM int,
           CAT VARCHAR(3),
           CUSTOMER8 varchar(10)
	);

	INSERT INTO BASE_YTD 
	SELECT * 
	FROM DT_YTD D CROSS JOIN T_CUST C;

	--
	
	CREATE OR REPLACE TEMPORARY TABLE TC_YTD (
		   CUST varchar(10),
		   DATE_ID int,
		   CAT varchar(3),
		   CY decimal(12,2),
		   PY decimal(12,2)
	);
	
	--
	INSERT INTO TC_YTD
	SELECT DT.CUSTOMER8, DT.DATE_ID, DT.CAT, SUM(IFF(TC.FY = 'CY', SLS, 0)) CY, SUM(IFF(TC.FY = 'PY', SLS, 0)) PY
	FROM   BASE_YTD DT
				  LEFT OUTER JOIN TC_YTD0 TC ON DT.MM = TC.MM AND DT.CAT = TC.CAT AND DT.CUSTOMER8 = TC.CUST
	GROUP BY DT.DATE_ID, DT.CAT, DT.CUSTOMER8;

	--
	
	CREATE OR REPLACE TABLE T_TRENDCAT (
		   CUST varchar(10),
		   TF char(2),
		   CAT varchar(3),
		   DATE_ID int,
		   CY decimal(12,2),
		   PY decimal(12,2)
	);

	-- Sales by days (fm)
	INSERT INTO T_TRENDCAT
	SELECT CUST, 'fm', CAT, DATE_ID, CY, PY FROM TC_MTD;


	-- Sales by month (fy)
	INSERT INTO T_TRENDCAT
	SELECT CUST, 'fy', CAT, DATE_ID, CY, PY FROM TC_YTD;


	-----------------------------------------------------------------------------------
	-- CREATE OUTPUT TABLES
	-----------------------------------------------------------------------------------
    CREATE OR REPLACE TEMPORARY TABLE CSR_CUST
    AS
    
        SELECT CUST, CUSTNUM, CUSTNAME, ESTABLISHED, LASTPURCHASED, CREDIT, CREDITTERMS, PASTDUE, FREIGHTTERMS
        FROM  T_CUSTDATA
    ;

    -- Timeframe Table (temporal):
    CREATE OR REPLACE TEMPORARY TABLE CSR_ITEMS
    AS
        SELECT	KEY, VALUE
        FROM	( VALUES
                    ('fm', 'MTD'), ('fy', 'YTD')
                )T ("key", "value")
    ;

	-- CAT Table (temporal):

    CREATE OR REPLACE TEMPORARY TABLE T_CATFILTER
    AS 
        SELECT	T0.CUST, T0.cat AS key, IFF(T0.cat = 'all', 'All', CAT_DESC) AS VALUE
        FROM	T_SPEND AS T0
                LEFT OUTER JOIN Dim_CAT AS T1
                    ON T0.CAT = T1.CAT
        WHERE	T0.CAT <> '0'
                AND ( T1.CAT_DESC IS NOT NULL OR T0.CAT = 'all' )
        GROUP BY ALL
    ;

    -- Spend Table:

    CREATE OR REPLACE TEMPORARY TABLE CSR_SPEND
	AS 
        SELECT	CUST, tf, cat, cy, py
        FROM	T_SPEND
    ;
	-- Orders Table:
    CREATE OR REPLACE TEMPORARY TABLE CSR_ORDERS
    AS 
        SELECT	CUST, tf, cat, cy, py
        FROM	T_ORD
    ;
	-- Trend Table:
    CREATE OR REPLACE TEMPORARY TABLE CSR_TREND
    AS
        SELECT	CUST, tf, cat, DATE_ID AS dt, cy, py
        FROM	T_TRENDCAT
    ;
	-- RCAT Table:
    CREATE OR REPLACE TEMPORARY TABLE CSR_CAT
    AS 
        SELECT	CUST, tf, T0.CAT AS cat, TRIM(CAT_DESC) AS catdesc, cy, py
        FROM	T_CAT AS T0 
                LEFT OUTER JOIN Dim_CAT AS T1
                    ON T0.CAT = T1.CAT
    ;



	-- RCAT Table:
    CREATE OR REPLACE TEMPORARY TABLE CSR_RCAT
    AS
        SELECT CUST, tf, T0.cat, T1.PRODUCT_GROUP_ID AS RCAT, REPLACE(TRIM(PRODUCT_GROUP_DESC), '&', '') AS rcatdesc, cy, py
        FROM T_RCAT AS T0
        LEFT OUTER JOIN Dim_PRODUCTGROUP AS T1
            ON T0.RCAT = T1.PRODUCT_GROUP_ID;
-- Vendors Table:

SELECT TOP 100 * fROM T_VEND;
SELECT TOP 100 * FROM Dim_SUPPLIER;

    CREATE OR REPLACE TEMPORARY TABLE CSR_VENDORS AS
            SELECT 
                CUST, 
                tf, 
                cat, 
                REPLACE(TRIM(T1.VENDOR_NAME), '&', '') AS vendor,
                CY_SLS AS slscy, 
                PY_SLS AS slspy, 
                CY_SLS - PY_SLS AS slsvar,
                CY_QTY AS qtycy, 
                PY_QTY AS qtypy
            FROM 
                T_VEND AS T0
            LEFT OUTER JOIN 
                Dim_SUPPLIER AS T1
            ON 
                T0.VENDOR = T1.LEGACY_VENDOR_NBR
	;


	SELECT TOP 100 * FROM T_ITEMSLS;
	SELECT TOP 100 * FROM DIM_ITEM;
	SELECT TOP 100 * fROM DIM_INVLOC;
	-- Items by sales Table:
	CREATE OR REPLACE TEMPORARY TABLE CSR_ITEMSLS AS
			SELECT 
				CUST, 
				tf, 
				T0.CAT AS cat, 
				REPLACE(TRIM(T2.VENDOR_NAME), '&', '') AS vendor, 
				REPLACE(TRIM(T1.ITEM_ID), '&', '') AS item, 
				REPLACE(TRIM(T1.ITEM_DESC), '&', '') AS itemdesc, 
				CY_SLS AS slscy, 
				PY_SLS AS slspy, 
				CY_SLS - PY_SLS AS slsvar, 
				CY_QTY AS qtycy, 
				PY_QTY AS qtypy
			FROM 
				T_ITEMSLS AS T0
			LEFT OUTER JOIN 
				Dim_ITEM AS T1
			ON 
				T0.ITEM = T1.ITEM_ID
			LEFT OUTER JOIN
				DIM_INVLOC AS T3
			ON	
				T1.ITEM_KEY = T3.ITEM_KEY
			LEFT OUTER JOIN 
				Dim_SUPPLIER AS T2
			ON 
				T3.SUPPLIER_KEY = T2.SUPPLIER_KEY
		;


	-- Items by quantities Table:
	CREATE OR REPLACE TEMPORARY TABLE CSR_ITEMQTY AS
		SELECT 
			CUST, 
			TF, 
			T0.CAT AS CAT, 
			REPLACE(TRIM(T2.VENDOR_NAME), '&', '') AS VENDOR, 
			REPLACE(TRIM(T1.ITEM_ID), '&', '') AS ITEM, 
			REPLACE(TRIM(T1.ITEM_DESC), '&', '') AS ITEMDESC, 
			CY_SLS AS SLSCY, 
			PY_SLS AS SLSPY, 
			CY_SLS - PY_SLS AS SLSVAR, 
			CY_QTY AS QTYCY, 
			PY_QTY AS QTYPY
		FROM 
			T_ITEMQTY AS T0
		LEFT OUTER JOIN 
			Dim_ITEM AS T1
		ON 
			T0.ITEM = T1.ITEM_ID
		LEFT OUTER JOIN
			DIM_INVLOC AS T3
		ON T3.ITEM_KEY = T1.ITEM_KEY
		LEFT OUTER JOIN 
			Dim_SUPPLIER AS T2
		ON 
			T2.SUPPLIER_KEY = T3.SUPPLIER_KEY
			
	;
	-- Returns Table:

		CREATE OR REPLACE TEMPORARY TABLE CSR_RETURNS AS
		SELECT 
			CUST, 
			TF, 
			T0.CAT AS CAT, 
			REPLACE(TRIM(T2.VENDOR_NAME), '&', '') AS VENDOR, 
			REPLACE(TRIM(T1.ITEM_ID), '&', '') AS ITEM, 
			REPLACE(TRIM(T1.ITEM_DESC), '&', '') AS ITEMDESC, 
			CY_SLS AS SLSCY, 
			PY_SLS AS SLSPY, 
			CY_SLS - PY_SLS AS SLSVAR, 
			CY_QTY AS QTYCY, 
			PY_QTY AS QTYPY
		FROM
			T_RETURNS AS T0
		LEFT OUTER JOIN
			Dim_ITEM AS T1
		ON	
			T0.ITEM = T1.ITEM_ID		
		LEFT OUTER JOIN	
			DIM_INVLOC T3
		ON	
			T1.ITEM_KEY = T3.ITEM_KEY
		LEFT OUTER JOIN
			Dim_SUPPLIER AS T2
		ON	
			T3.SUPPLIER_KEY = T2.SUPPLIER_KEY
	;

	-- Create the final table for quotes
	CREATE OR REPLACE TEMPORARY TABLE CSR_QUOTES AS
	SELECT
		CUST,
		tf,
		dt,
		city,
		ST AS state,
		ORDER_NBR AS ordernbr,
		EMP_NAME AS tknby,
		ORDER_AMT AS amount
	FROM
		T_QUOTES;
		
		-- Create the final table for projects
	CREATE OR REPLACE TEMPORARY TABLE CSR_PROJECTS AS
		SELECT
			CUST,
			tf,
			dt,
			city,
			ST AS state,
			ORDER_NO AS ordernbr,
			EMP_NAME AS tknby,
			ORDER_AMT AS amount
		FROM
			T_PROJECTS
	;

 -- Create the final OBJECTS
	CREATE OR REPLACE TEMPORARY TABLE T_CUST_DATA AS
		SELECT 
		CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('custnum', custnum, 'custname', custname, 'established', established, 'lastpurchased', lastpurchased, 'credit', credit, 'creditterms', creditterms, 'pastdue', pastdue, 'freightterms', freightterms))
				FROM CSR_CUST
				WHERE CUST = CUSTOMER8
			) AS CUST_DATA,
		FROM T_CUST
	;

	CREATE OR REPLACE TEMPORARY TABLE T_SPEND AS
		SELECT CUSTOMER8 AS CUSTOMER_NUM, 
		(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('tf', tf, 'cat', cat, 'cy', cy, 'py', py))
				FROM CSR_SPEND
				WHERE CUST = CUSTOMER8
			) AS SPEND
		FROM T_CUST
	;

	CREATE OR REPLACE TEMPORARY TABLE T_ORDERS AS
		SELECT CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('tf', tf, 'cat', cat, 'cy', cy, 'py', py))
				FROM CSR_ORDERS
				WHERE CUST = CUSTOMER8
			) AS ORDERS
			FROM T_CUST
	;

	CREATE OR REPLACE TEMPORARY TABLE T_TREND AS

		SELECT CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('tf', tf, 'cat', cat, 'dt', dt, 'cy', cy, 'py', py))
				FROM CSR_TREND
				WHERE CUST = CUSTOMER8
				ORDER BY tf, cat, dt
			) AS TREND
			FROM T_CUST
	;

	CREATE OR REPLACE TEMPORARY TABLE CAT AS 
		SELECT CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('tf', tf, 'cat', cat, 'catdesc', catdesc, 'cy', cy, 'py', py))
				FROM CSR_CAT
				WHERE CUST = CUSTOMER8
				ORDER BY tf, catdesc
			) AS CAT
			FROM T_CUST
	;

	CREATE OR REPLACE TEMPORARY TABLE T_RCAT AS 
		SELECT CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('tf', tf, 'cat', cat, 'rcatdesc', rcatdesc, 'cy', py, 'py', py))
				FROM CSR_RCAT
				WHERE CUST = CUSTOMER8
				ORDER BY tf, cat, cy DESC
			) AS RCAT
		FROM T_CUST
	;
	CREATE OR REPLACE TEMPORARY TABLE T_VENDORS AS
		SELECT CUSTOMER8 AS CUSTOMER_NUM,
		(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('tf', tf, 'cat', cat, 'vendor', vendor, 'slscy', slscy, 'slspy', slspy, 'slsvar', slsvar, 'qtycy', qtycy, 'qtypy', qtypy))
				FROM CSR_VENDORS
				WHERE CUST = CUSTOMER8
			) AS VENDORS
		FROM T_CUST
	;

	CREATE OR REPLACE TEMPORARY TABLE T_ITEMS_SLS AS
		SELECT CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('tf', tf, 'cat', cat, 'vendor', vendor, 'item', item, 'itemdesc', itemdesc, 'slscy', slscy, 'slspy', slspy, 'slsvar', slsvar, 'qtycy', qtycy, 'qtypy', qtypy))
				FROM CSR_ITEMSLS
				WHERE CUST = CUSTOMER8
			) AS ITEM_SLS
		FROM T_CUST
	;

	CREATE OR REPLACE TEMPORARY TABLE T_ITEMQTY AS
		SELECT CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('tf', tf, 'cat', cat, 'vendor', vendor, 'item', item, 'itemdesc', itemdesc, 'slscy', slscy, 'slspy', slspy, 'slsvar', slsvar, 'qtycy', qtycy, 'qtypy', qtypy))
				FROM CSR_ITEMQTY
				WHERE CUST = CUSTOMER8
			) AS ITEM_QTY
		FROM T_CUST
	;
	
	CREATE OR REPLACE TEMPORARY TABLE T_RETURNS AS
		SELECT CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('tf', tf, 'cat', cat, 'vendor', vendor, 'slscy', slspy, 'slspy', slspy, 'slsvar', slsvar, 'qtycy', qtycy, 'qtypy', qtypy))
				FROM CSR_RETURNS
				WHERE CUST = CUSTOMER8
			) AS RETURNS
		FROM T_CUST
	;
	
	CREATE OR REPLACE TEMPORARY TABLE T_QUOTES AS 
		SELECT CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('tf', tf, 'dt', dt, 'city', city, 'state', state, 'ordernbr', ordernbr, 'tknby', tknby, 'amount', amount))
				FROM CSR_QUOTES
				WHERE CUST = LEFT(CUSTOMER8, 5)
			) AS QUOTES
		FROM T_CUST
	;
	CREATE OR REPLACE TEMPORARY TABLE T_PROJECTS AS
		SELECT CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('tf', tf, 'dt', dt, 'city', city, 'state', state, 'ordernbr', ordernbr, 'tknby', tknby, 'amount', amount))
				FROM CSR_PROJECTS
				WHERE CUST = LEFT(CUSTOMER8, 5)
			) AS PROJECTS
		FROM T_CUST
	;
	
	CREATE OR REPLACE TEMPORARY TABLE T_TF AS
		SELECT CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('key', key, 'value', value))
				FROM CSR_ITEMS
			) AS TF
		FROM T_CUST
	;

	CREATE OR REPLACE TEMPORARY TABLE T_CATEGORY AS
		SELECT CUSTOMER8 AS CUSTOMER_NUM,
			(
				SELECT ARRAY_AGG(OBJECT_CONSTRUCT('key', key, 'value', value))
				FROM T_CATFILTER
				WHERE CUST = CUSTOMER8
				ORDER BY IFF(key = 'all', 1, 2), value ASC
			) AS CATEGORY
		FROM T_CUST
	;

-- CONSOLIDATE ALL THE TABLES INTO ONE TABLE
	CREATE OR REPLACE TABLE DB_ADI_NA_DEV.SCH_ADI_NA_CORE.TBL_CSR_DATA(
		ORIGIN VARCHAR(10),
		CUSTOMER_NUM VARCHAR(10),
		CUST_DATA VARIANT,
		SPEND VARIANT,
		ORDERS VARIANT,
		TREND VARIANT,
		CAT VARIANT,
		RCAT VARIANT,
		VENDORS VARIANT,
		ITEM_SLS VARIANT,
		ITEM_QTY VARIANT,
		RETURNS VARIANT,
		QUOTES VARIANT,
		PROJECTS VARIANT,
		TF VARIANT,
		CATEGORY VARIANT
	);
	
	-- INSERT INTO DB_ADI_NA_DEV.SCH_ADI_NA_CORE.TBL_CSR_DATA
	--	(ORIGIN, CUSTOMER_NUM, CUST_DATA, SPEND, ORDERS, TREND, CAT, RCAT, VENDORS, ITEM_SLS, ITEM_QTY, RETURNS, QUOTES, PROJECTS, TF, CATEGORY)
	CREATE OR REPLACE TEMPORARY TABLE T_P21_OUTPUT AS
	SELECT 'P21' AS ORIGIN, T_CUST_DATA.CUSTOMER_NUM, CUST_DATA, SPEND, ORDERS, TREND, CAT, RCAT, VENDORS, ITEM_SLS, ITEM_QTY, RETURNS, QUOTES, PROJECTS, TF, CATEGORY
	FROM T_CUST_DATA
		LEFT JOIN T_SPEND 
			ON T_CUST_DATA.CUSTOMER_NUM = T_SPEND.CUSTOMER_NUM
		LEFT JOIN T_ORDERS
			ON T_CUST_DATA.CUSTOMER_NUM = T_ORDERS.CUSTOMER_NUM
		LEFT JOIN T_TREND
			ON T_CUST_DATA.CUSTOMER_NUM = T_TREND.CUSTOMER_NUM
		LEFT JOIN CAT
			ON T_CUST_DATA.CUSTOMER_NUM = CAT.CUSTOMER_NUM
		LEFT JOIN T_RCAT
			ON T_CUST_DATA.CUSTOMER_NUM = T_RCAT.CUSTOMER_NUM
		LEFT JOIN T_VENDORS
			ON T_CUST_DATA.CUSTOMER_NUM = T_VENDORS.CUSTOMER_NUM
		LEFT JOIN T_ITEMS_SLS
			ON T_CUST_DATA.CUSTOMER_NUM = T_ITEMS_SLS.CUSTOMER_NUM
		LEFT JOIN T_ITEMQTY
			ON T_CUST_DATA.CUSTOMER_NUM = T_ITEMQTY.CUSTOMER_NUM
		LEFT JOIN T_RETURNS
			ON T_CUST_DATA.CUSTOMER_NUM = T_RETURNS.CUSTOMER_NUM
		LEFT JOIN T_QUOTES
			ON T_CUST_DATA.CUSTOMER_NUM = T_QUOTES.CUSTOMER_NUM
		LEFT JOIN T_PROJECTS
			ON T_CUST_DATA.CUSTOMER_NUM = T_PROJECTS.CUSTOMER_NUM
		LEFT JOIN T_TF
			ON T_CUST_DATA.CUSTOMER_NUM = T_TF.CUSTOMER_NUM
		LEFT JOIN T_CATEGORY
			ON T_CUST_DATA.CUSTOMER_NUM = T_CATEGORY.CUSTOMER_NUM
	;

	-- SELECT * FROM DB_ADI_NA_DEV.SCH_ADI_NA_CORE.TBL_CSR_DATA;

	-- P21 DATA OUTPUT


------------------------------------------------------------------------------------------------
