USE [AllOfUs_Mart]
GO
/****** Object:  StoredProcedure [dbo].[pii_transform]    Script Date: 8/30/2024 8:43:09 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[pii_transform]  as

	declare addresses cursor local for
		select p.person_id, cap.[eADDRESS_LINE1] as eaddress_1, cap.[eADDRESS_LINE2] as eaddress_2, cap.[eCITY], cap.[STATE], cap.[eZIP] 
		from econstrack_aou_participants cap
		join person p on substring(cap.[PERSON_ID], 2, 12) = p.person_id;

	declare @person_id integer, 
			@eaddress_1 varbinary(255), 
			@eaddress_2 varbinary(255), 
			@ecity varbinary(255), 
			@state varchar(120), 
			@ezip varbinary(255), 
			@location_id integer

	begin

		OPEN SYMMETRIC KEY <key> DECRYPTION
		by certificate <cert>

		--Clear all previous values
		delete from cPII_NAME;
		delete from cPII_EMAIL;
		delete from cPII_PHONE_NUMBER;
		delete from cPII_MRN;

		delete from ePII_NAME;
		delete from ePII_EMAIL;
		delete from ePII_PHONE_NUMBER;
		delete from ePII_MRN;

		delete from elocation;
		delete from PII_ADDRESS;

		insert into dbo.ePII_NAME
			select p.person_id, cap.[eFIRSTNAME] as first_name, cap.[eMIDDLE_NAME], cap.[eLASTNAME] as last_name, cap.[SUFFIX], cap.[PREFIX] 
			from econstrack_aou_participants cap
			join person p on substring(cap.[PERSON_ID], 2, 12) = p.person_id

		insert into dbo.ePII_PHONE_NUMBER
			select p.person_id, cap.[eWORK_PHONE] as phone_number from econstrack_aou_participants cap
			join person p on substring(cap.[PERSON_ID], 2, 12) = p.person_id where cap.[eWORK_PHONE] is not null and cap.[eWORK_PHONE] != ''
			union
			select p.person_id, cap.[eHOME_PHONE] as phone_number from econstrack_aou_participants cap
			join person p on substring(cap.[PERSON_ID], 2, 12) = p.person_id where cap.[eHOME_PHONE] is not null and cap.[eHOME_PHONE] != ''

		insert into dbo.ePII_MRN
		select p.person_id, amm.company_cd as health_system, mm.emrn
				from econstrack_aou_participants cap
				join person p on substring(cap.[PERSON_ID], 2, 12) = p.person_id
				join eaou_mapping am on am.pmi_id = cap.[PERSON_ID]
				join emrn_mapping mm on CONVERT(varchar(100),DECRYPTBYKEY(mm.emrn)) = CONVERT(varchar(100),DECRYPTBYKEY(am.emrn)) and am.mrn_facility = mm.company_cd 
				join emrn_mapping amm on CONVERT(varchar(100),DECRYPTBYKEY(mm.eempi)) = CONVERT(varchar(100),DECRYPTBYKEY(amm.eempi))
				where amm.emrn is not null and amm.emrn != '';

		open addresses;

		fetch next from addresses  into @person_id, @eaddress_1, @eaddress_2, @ecity, @state, @ezip;

		while @@fetch_status=0

			begin	
	
				SET @location_id = NEXT VALUE FOR location_id_Seq;
 
				insert into elocation (location_id, eaddress_1, eaddress_2, ecity, state, ezip, ecounty, location_source_value)
					values (@location_id, @eaddress_1, @eaddress_2, @ecity, @state, @ezip, null, null);
 
				insert into PII_ADDRESS (person_id, location_id) values (@person_id, @location_id);

				fetch next from addresses  into @person_id, @eaddress_1, @eaddress_2, @ecity, @state, @ezip;

			end

		CLOSE SYMMETRIC KEY <key>	

	end
