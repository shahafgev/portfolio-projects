------CREATING THE TABLES
--DROP TABLE SHIFTS
CREATE TABLE SHIFTS(
[Date]				date			NOT NULL,
[Type]				varchar(20)		NOT NULL,
[Within the city]	int				NOT NULL,
[Outside the city]	int				NOT NULL,
Tips int,
Distance int						NOT NULL,
[Food expenses] int DEFAULT 0,
[Gas refund] int DEFAULT 50
CONSTRAINT PK_SHIFTS PRIMARY KEY ([Date], [Type]),
CONSTRAINT FK_SHIFTTYPE FOREIGN KEY ([Type]) REFERENCES SHIFTTYPE([Type])
)

--DROP TABLE GASPRICE
CREATE TABLE GASPRICE(
[From]	date	NOT NULL,
Price	real	NOT NULL,
CONSTRAINT PK_GASPRICE PRIMARY KEY ([From], Price)
)

--DROP TABLE SHIFTTYPE
CREATE TABLE SHIFTTYPE(
[Type]	varchar(20) PRIMARY KEY NOT NULL,
[Hours] int						NOT NULL
)
--------------------------------------------------------------
-----USING LEAD TO CREATE A GAS PRICES TABLE BOUNDED BY START & END DATE
--SELECT	[From], 
--		DATEADD(DAY, -1,  LEAD([From], 1) OVER(ORDER BY [From]))AS [To],
--		Price
--FROM GASPRICE

-----FUNCTION WHO RECIEVES A DATE AND RETURNES THE RELEVENT GAS COST FOR 1 KM
--DROP FUNCTION ReleventGasPrice
CREATE FUNCTION ReleventGasPrice(@Date DATE)
RETURNS REAL
AS BEGIN
		DECLARE @OUTPUT REAL
			SELECT	@OUTPUT =  G.Price
			FROM	(	SELECT	[From], 
						DATEADD(DAY, -1,  LEAD([From], 1) OVER(ORDER BY [From]))AS [To],
						Price
						FROM GASPRICE
					) AS G
			WHERE	@Date >= G.[From] AND (@Date<= G.[To] OR G.[To] IS NULL)
		RETURN @OUTPUT
		END

--FUNCTION CHECK
--SELECT dbo.ReleventGasPrice('2022-12-04') 
----------------------------------------------------VIEWS
--DROP VIEW V_SHIFTS
CREATE VIEW V_SHIFTS AS
	SELECT *,	[Gas expenses] = ROUND (Distance * (SELECT dbo.ReleventGasPrice([Date])), 2),
				[Profit] = 18* [Within the city] + 50* [Outside the city] + Tips - [Food expenses] + [Gas refund] 
				- ROUND (Distance * (SELECT dbo.ReleventGasPrice([Date])), 2)
	FROM SHIFTS

--DROP VIEW V_SHIFTS2
CREATE VIEW V_SHIFTS2 AS
	SELECT	V1.Date, V1.Type, DATENAME(WEEKDAY, V1.Date) AS [WeekDay], S.Hours,  
			V1.[Within the city], V1.[Outside the city], 
			V1.Tips, V1.Distance, V1.[Food expenses], 
			V1.[Gas refund], V1.[Gas expenses], V1.Profit
	FROM	V_SHIFTS AS V1  JOIN SHIFTTYPE AS S ON S.[Type] = V1.[Type]

--DROP VIEW V_SHIFTS3
CREATE VIEW V_SHIFTS3 AS
	SELECT	S.[WeekDay] ,S.Type,
			RANK() OVER (ORDER BY CAST(SUM(S.Profit) AS DECIMAL (7,2))/CAST(COUNT(DISTINCT S.Date) AS DECIMAL(7,2)) DESC) [Rank],
			[Total Deliveries] = SUM(S.[Outside the city] + S.[Within the city]),
			[Number of shifts] = COUNT(DISTINCT S.Date),
			[Total tips] = SUM(S.Tips),
			[Total Distance] = SUM(S.Distance),
			[Total Gas expenses] = SUM(S.[Gas expenses]),
			[Total Profit] = SUM(S.Profit),
			[Total Hours] = SUM(S.Hours),
			[Average Deliveries] = CAST(SUM(S.[Outside the city] + S.[Within the city]) AS DECIMAL(5,2)) / CAST(COUNT(DISTINCT S.Date) AS DECIMAL(5,2)),
			[Average tip] = CAST(SUM(S.Tips) AS DECIMAL(5,2))/CAST(COUNT(DISTINCT S.Date) AS DECIMAL(5,2)),
			[Average Distance] = CAST(SUM(S.Distance) AS DECIMAL(5,2))/CAST(COUNT(DISTINCT S.Date) AS DECIMAL (5,2)),
			[Average Gas expenses] = CAST(SUM(S.[Gas expenses]) AS DECIMAL(5,2))/CAST(COUNT(DISTINCT S.Date) AS DECIMAL(5,2)),
			[Average Profit] = CAST(SUM(S.Profit) AS DECIMAL (7,2))/CAST(COUNT(DISTINCT S.Date) AS DECIMAL(7,2)),
			[Average Profit for hour] = CAST(SUM(S.Profit) AS DECIMAL (7,2))/CAST(SUM(S.Hours) AS DECIMAL(7,2))
	FROM V_SHIFTS2 AS S
	WHERE S.Type NOT IN ('Reinforcement')
	GROUP BY S.[WeekDay], S.Type

--DROP VIEW V_SHIFTS4
CREATE VIEW V_SHIFTS4 AS
	SELECT	V2.Date, V2.[Type], V2.[WeekDay], V2.Profit , [Average Profit from same shift]= V3.[Average Profit],
			[Compared to the average profit from the same shift] = (V2.Profit-V3.[Average Profit])/V3.[Average Profit],
			[Average shift profit] = (SELECT AVG(V.[Profit]) FROM V_SHIFTS AS V),
			[Compared to the average shift profit] = (V2.Profit-(SELECT AVG(V.[Profit]) FROM V_SHIFTS AS V))/(SELECT AVG(V.[Profit]) FROM V_SHIFTS AS V)
	FROM V_SHIFTS2 AS V2 JOIN V_SHIFTS3 AS V3 ON V2.[WeekDay] = V3.[WEEKDAY] AND V2.Type = V3.Type
	GROUP BY V2.DATE, V2.[Type], V2.[WeekDay], V2.Profit, V3.[Average Profit]
--------------------------------------------------

