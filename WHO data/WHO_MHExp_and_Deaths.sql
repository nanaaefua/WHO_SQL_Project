/****** Script for SelectTopNRows command from SSMS  ******/
DROP TABLE IF EXISTS dbo.WHO_MHExp_and_Deaths;

WITH icdTotal AS
   (SELECT * FROM [ICD10].[dbo].[Morticd10_part1] UNION 
	SELECT * FROM [ICD10].[dbo].[Morticd10_part2] UNION 
	SELECT * FROM [ICD10].[dbo].[Morticd10_part3] UNION 
	SELECT * FROM [ICD10].[dbo].[Morticd10_part4] UNION 
	SELECT * FROM [ICD10].[dbo].[Morticd10_part5]),

	Deaths_by_Suicides AS --Have Deaths by Suicide by Country Name and Year, with Population and Total Deaths
   (SELECT 
		country.name as Country_Name, 
		p.Year as [Year], 
		AVG(cast([Pop1] AS float))*2 as Pop1, --*2 for both sexes count
		SUM(cast([Deaths1] AS INT))/2 as Deaths_All_Ages, --/2 for both sexes repetition in pop
		SUM(CASE WHEN -- List 103 for ICD10-3, Suicide Causes: X60-X84,Y870,U03
				icdTotal.List = '103'  AND (icdTotal.Cause BETWEEN 'X60' AND 'X84' OR icdTotal.Cause = 'U03') 
				OR (icdTotal.List = '104' AND icdTotal.Cause = 'Y870') 
				OR (list = '101' AND icdTotal.Cause = '1101')  
			THEN cast([Deaths1] AS INT)
			ELSE 0 
			END)/2 AS Deaths_Suicides --/2 for both sexes repetition in pop
	FROM [dbo].[WHO_pop] p
	LEFT JOIN icdTotal ON p.Country=icdTotal.country AND p.Year=icdTotal.Year
	LEFT JOIN [dbo].[Country_Dictionaries] country  ON country.country=p.Country
	GROUP BY country.name,p.Year)


    SELECT
		Country_Name,[Year], str(Pop1,20,2) AS Population --Population
		,Deaths_All_Ages AS Deaths_All_Types, Deaths_Suicides --Deaths in ICD10
		,str(ROUND(AVG(HE.Value),2),20,2) AS HExp_Pctage_Y, STR(ROUND(AVG(MHE.Value),2),20,2) AS MHExp_Pctage_2011 --Expenditure
		,STR(ROUND(AVG(CAST(LEFT(DEP.[Value],CHARINDEX('[',DEP.[Value])-2) AS float)),2),20,2) AS Dep_Num_2015, STR(ROUND(AVG(CAST(LEFT(SUI.[Value],CHARINDEX('[',SUI.[Value])-2) AS float)),2),20,2) AS Suicide_p100 --Depression and suicides estimated rates
    INTO WHO_MHExp_and_Deaths --all extracted as string with 2 decimals str(@f,'N',2)
	FROM Deaths_by_Suicides--,Death_All,Pop
    LEFT JOIN [dbo].[Age-Standardizes_suicide_p100] SUI ON SUI.Period=Deaths_by_Suicides.Year AND SUI.Location=Deaths_by_Suicides.Country_Name
    LEFT JOIN [dbo].[HealthExpend_GDP_Pctage] HE ON HE.Period=Deaths_by_Suicides.Year AND HE.Location=Deaths_by_Suicides.Country_Name
    LEFT JOIN [dbo].[MentalHealthExpend_GDP_Pctage] MHE ON MHE.Location=Deaths_by_Suicides.Country_Name --for all years as a reference
    LEFT JOIN [dbo].[Estimated_depression] DEP ON DEP.Location=Deaths_by_Suicides.Country_Name --for all years as a reference

	WHERE Deaths_All_Ages IS NOT NULL AND HE.Value IS NOT NULL AND MHE.Value IS NOT NULL AND SUI.Dim1 = 'Both sexes'
	GROUP BY Country_Name,deaths_by_suicides.year,Pop1,Deaths_All_Ages,Deaths_Suicides
    ORDER BY 1,2

-- get: % of death by population, % of suicides by deaths, % of health by gdp, all in map, with corr