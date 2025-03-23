-- Creating new database 
IF NOT EXISTS (
    SELECT 1 
    FROM sys.databases 
    WHERE name = 'youtube_db'
)
BEGIN
    CREATE DATABASE youtube_db;
END;

-- Switch context to the DB
USE youtube_db;

/*===============================================================*/
/* ----- IMPORTING RAW DATA AND CLEANING IT ----- */

-- use SSMS GUI to import flat .csv file 

-- Quick preview from SSMS GUI | click right on table -> "select top 1000 rows"
SELECT TOP (1000) [Column_1]
      ,[NOMBRE]
      ,[SEGUIDORES]
      ,[TP]
      ,[PAÍS]
      ,[TEMA_DE_INFLUENCIA]
      ,[ALCANCE_POTENCIAL]
      ,[GUARDAR]
      ,[INVITAR_A_LA_CAMPAÑA]
      ,[channel_name]
      ,[total_subscribers]
      ,[total_views]
      ,[total_videos]
      ,[column14]
  FROM [youtube_db].[dbo].[top_uk_youtubers_2024];

/* ----- SELECTING COLUMNS FOR ANALYSIS ----- */
SELECT	
	NOMBRE,
	total_subscribers,
	total_views,
	total_videos
FROM top_uk_youtubers_2024;

/* ----- SPLIT TEXT IN COLUMN "NOMBRE" ----- */
-- Column "NOMBRE" seems to have an string with "channel_name @ channel_id"

/*===========================================================================*/
-- PROTOTYPING 
DECLARE @chn_name NVARCHAR(100) = '1234567@ UC-abc123xyz';
SELECT
	CHARINDEX('@', @chn_name) AS position_of_at; /* out: 8*/

-- -------------------------------------------------
-- SUBSTRING ( expression, start, length ) 
DECLARE @chn_name NVARCHAR(100) = '1234567@ UC-abc123xyz';
SELECT 
	SUBSTRING(
		@chn_name, 
		1, 
		CHARINDEX('@', @chn_name)
	) AS position_of_at; /* out:'1234567@' */


-- -------------------------------------------------
-- Ensuring data type VARCHAR allowing only 100 characters
-- Adding TRIM to remove blank spaces in the string: " dfd df " -> "dfd df"
DECLARE @chn_name NVARCHAR(100) = '  1234 567@ UC-abc123xyz  ';
SELECT 
	CAST(
		TRIM(
			SUBSTRING(
				@chn_name, 
				1, 
				CHARINDEX('@', @chn_name)-1
			)
		) AS VARCHAR(100)
	) AS channel_name;

-- -------------------------------------------------
-- Extracting channel_id
DECLARE @chn_name NVARCHAR(100) = '  1234 567@ UC abc123xyz  ';
SELECT 
    CAST(
        TRIM(
            SUBSTRING(
                @chn_name,
                CHARINDEX('@', @chn_name) + 1,
                LEN(@chn_name)
            )
        ) AS VARCHAR(100)
    ) AS channel_id;

-- -------------------------------------------------
WITH cte_slctd_cols AS (
    SELECT 
        NOMBRE,
        CAST(TRIM(SUBSTRING(NOMBRE, 1, CHARINDEX('@', NOMBRE) - 1)) AS VARCHAR(100)) AS channel_name,
        CAST(TRIM(SUBSTRING(NOMBRE, CHARINDEX('@', NOMBRE) + 1, LEN(NOMBRE))) AS VARCHAR(100)) AS channel_id,
        total_subscribers,
        total_views,
        total_videos
    FROM top_uk_youtubers_2024
) 
SELECT 
    channel_name,
    channel_id,
    total_subscribers,
    total_views,
    total_videos
FROM cte_slctd_cols;

GO  -- separates this from any earlier code
CREATE VIEW view_slctd_cols AS 
SELECT 
    NOMBRE,
    CAST(TRIM(SUBSTRING(NOMBRE, 1, CHARINDEX('@', NOMBRE) - 1)) AS VARCHAR(100)) AS channel_name,
    CAST(TRIM(SUBSTRING(NOMBRE, CHARINDEX('@', NOMBRE) + 1, LEN(NOMBRE))) AS VARCHAR(100)) AS channel_id,
    total_subscribers,
    total_views,
    total_videos
FROM top_uk_youtubers_2024;

GO  -- separates this from any earlier code
ALTER VIEW view_slctd_cols AS
SELECT
    CAST(TRIM(SUBSTRING(NOMBRE, 1, CHARINDEX('@', NOMBRE) - 1)) AS VARCHAR(100)) AS channel_name,
    CAST(TRIM(SUBSTRING(NOMBRE, CHARINDEX('@', NOMBRE) + 1, LEN(NOMBRE))) AS VARCHAR(100)) AS channel_id,
    total_subscribers,
    total_views,
    total_videos
FROM top_uk_youtubers_2024;
GO 


/*===============================================================*/
/* ----- DATA QUALITY HEALTHY CHECKS ----- */

/*
-- What we expect from this data | aspects to explore
1. Top 100 youtubers - row counts
2. Columns formats
3. Nulls 
4. Duplicates

-- EXPECTED DATA TYPE PER COLUMN:
channel_name: VARCHAR(100),
channel_id: VARCHAR(100),
total_subscribers: INT,
total_views: INT,
total_videos: INT

*/
-- -------------------------------------------------------------
-- Row Counts
SELECT COUNT(*) AS no_of_rows
FROM view_slctd_cols;

-- -------------------------------------------------------------
-- EXPLORING METADATA OF SELECTED COLUMNS VIEW
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'view_slctd_cols';
-- col: 'total_views' is float

-- -------------------------------------------------------------
-- Before changing data type, check which instances (rows) has decimals 
-- Check if there are any decimal values in total_views
IF NOT EXISTS (
    SELECT 1
    FROM top_uk_youtubers_2024
    WHERE total_views - FLOOR(total_views) <> 0
)
BEGIN
    PRINT 'No decimals found. Updating the view...';

	EXEC('
    ALTER VIEW view_slctd_cols AS
    SELECT
        CAST(TRIM(SUBSTRING(NOMBRE, 1, CHARINDEX(''@'', NOMBRE) - 1)) AS VARCHAR(100)) AS channel_name,
        CAST(TRIM(SUBSTRING(NOMBRE, CHARINDEX(''@'', NOMBRE) + 1, LEN(NOMBRE))) AS VARCHAR(100)) AS channel_id,
        total_subscribers,
        CAST(total_views AS BIGINT) AS total_views,
        total_videos
    FROM top_uk_youtubers_2024;
	');
END
ELSE
BEGIN
    PRINT 'Warning: Some rows contain decimal values in total_views. View not updated.';
END


-- -------------------------------------------------------------
-- CHECKING DUPLICATES
SELECT
	channel_name,
	COUNT(*) AS duplicate_count
FROM view_slctd_cols
GROUP BY channel_name
HAVING COUNT(*) > 1;

SELECT
	channel_id,
	COUNT(*) AS duplicate_count
FROM view_slctd_cols
GROUP BY channel_id
HAVING COUNT(*) > 1;

SELECT
	channel_id,
	COUNT(*) AS duplicate_count
FROM view_slctd_cols
GROUP BY channel_id
HAVING COUNT(*) > 1;

/*======================================*/
-- Switch context to the DB
USE youtube_db;

-- Select final view table to export
SELECT *
FROM view_slctd_cols;


SELECT @@SERVERNAME;