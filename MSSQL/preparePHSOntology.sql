---------------------------------------------------------------------------------------------
-- Mass General Brigham specific modifications 
-- Description: i2o_transform works off the PCORNET ARCH ontologies, following script
--              --Prepares the transformation to use i2b2 ontoloies in certain circumstances
-- Authored by: Jeff Klann
-- Updated by: Kevin Embree on 2020-12-07 to use units specified in the MGB i2b2 XML
--             Added extraction of xml creationDateTime onto i2b2metadata
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- When to run....
-- After preparePCORnetOntology.sql 
--	   Run the new preparePHSOntology.sql
-- Run after import of a new i2b2metadata ontology table.
--     This is done with each delivery of a new data mart.
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
-- Set up the extra columns ...
-- i_stdcode for standard code extracted from c_metadataxml
-- i_stddomain for the type of code was extracted from c_metadataxml ('LOINC', 'RXNORM', 'ICD9', etc...)
-- i_unit for the unit of measure used for the given code ('Inches', 'rbc/1 ml', etc ...)
-- i_date_of_xml_creation for the date the xml was created
--------------------------------------------------------------------------------------------
ALTER TABLE [dbo].[i2b2metadata]
	ADD [i_stdcode] varchar(100) NULL, 
	[i_stddomain] varchar(100) NULL,
	[i_unit] varchar(100) NULL,
	[i_date_of_xml_creation] date
GO
CREATE NONCLUSTERED INDEX [i2b2meta_stdcode]
	ON [dbo].[i2b2metadata]([i_stdcode])
GO

-- Chris' approach, use a view
drop view vw_labtests_reconstructed
GO
create view vw_LabTests_Reconstructed
as
with t as (
select l.c_name,
       l.c_basecode,
       f.ENCOUNTER_NUM,
       f.PATIENT_NUM,
       f.VALTYPE_CD,
       f.NVAL_NUM,
       f.TVAL_CHAR,
       f.VALUEFLAG_CD,
       try_cast(l.c_metadataxml as xml) valuexml
from i2b2metadata l
       inner join observation_fact f on l.C_BASECODE = f.CONCEPT_CD
where l.c_fullname like '\I2B2MetaData\LabTests\%')
select c_name LabName,
       C_BASECODE Concept_Cd,
       ENCOUNTER_NUM Encounter_Num,
       PATIENT_NUM Patient_Num,
       VALTYPE_CD ValueType,
       NVAL_NUM NumericValue,
       TVAL_CHAR TextValue,
       VALUEFLAG_CD ValueFlag,
       valuexml,
       valuexml.value('(/ValueMetadata/Loinc)[1]','VARCHAR(100)') Loinc,
valuexml.value('(/ValueMetadata/LowofLowValue)[1]','VARCHAR(100)') RefLowofLow,
valuexml.value('(/ValueMetadata/HighofLowValue)[1]','VARCHAR(100)') RefHighofLow,
valuexml.value('(/ValueMetadata/LowofHighValue)[1]','VARCHAR(100)') RefLowofHigh,
valuexml.value('(/ValueMetadata/HighofHighValue)[1]','VARCHAR(100)') RefHighofHigh,
valuexml.value('(/ValueMetadata/UnitValues/NormalUnits)[1]','VARCHAR(100)') Units
from t
GO

-------------------------------------------------------------------------------------------------------------
-- Extract all LOINC codes, units, and xmll date of creation from c_metadataxml
-------------------------------------------------------------------------------------------------------------
update m set i_stddomain='LOINC'
      ,i_stdcode=try_cast(m.c_metadataxml as xml).value('(/ValueMetadata/Loinc)[1]','VARCHAR(50)')
	  , i_unit = try_cast(m.c_metadataxml as xml).value('(/ValueMetadata/UnitValues/NormalUnits)[1]','VARCHAR(25)')
	  , i_date_of_xml_creation = try_cast(m.c_metadataxml as xml).value('(/ValueMetadata/CreationDateTime)[1]','DateTime')
	  from i2b2metadata m 
 where m.C_FULLNAME like '%\I2B2MetaData\LabTests\%'
 and m.c_metadataxml is not null
 and m.c_metadataxml != ''
GO
-- Create the new views - change COVID_Mart to your DB name
IF  EXISTS (SELECT * FROM sys.views WHERE name = N'i2o_ontology_lab') DROP VIEW i2o_ontology_lab
IF  EXISTS (SELECT * FROM sys.views WHERE name = N'i2o_ontology_drug') DROP VIEW i2o_ontology_drug
GO
create view i2o_ontology_lab as (select * from AllOfUs_Mart..i2b2metadata where i_stddomain='LOINC')
GO
create view i2o_ontology_drug as (select * from AllOfUs_Mart..pcornet_med where i_stddomain='RxNorm' or i_stddomain='NDC')
GO