/***********************************************
Various functions for manipulating bit flags in integer (bigint) values
http://www.sqlservercentral.com/scripts/T-SQL/61457/

See Example script below;

***********************************************/
-----------------------------------------------------------------------------------
-- Check if bigint Bit is ON
-----------------------------------------------------------------------------------
IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[fnBitIsOn]') AND xtype in (N'FN', N'IF', N'TF'))
	DROP FUNCTION [dbo].[fnBitIsOn]
Go

CREATE FUNCTION dbo.fnBitIsOn (@BitMap BIGINT, @BitNo TINYINT = 0) RETURNS TINYINT
-- v1.0.0 2006.09.26, Ofer Bester
AS BEGIN
	IF (@BitNo > 63)
 		RETURN 0
 
	IF (@BitNo = 63) 
	BEGIN
 		IF (@BitMap >= 0)
 			RETURN 0
	 	ELSE
 			RETURN 1
	END
 
	IF ( @BitMap & POWER( CAST(2 AS BIGINT), @BitNo ) ) <> 0
		RETURN 1

	RETURN 0
END
GO

-----------------------------------------------------------------------------------
-- Set bigint Bit OFF
-----------------------------------------------------------------------------------
IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[fnBitSetOff]') AND xtype in (N'FN', N'IF', N'TF'))
	DROP FUNCTION [dbo].[fnBitSetOff]
Go

CREATE FUNCTION dbo.fnBitSetOff (@BitMap BIGINT, @BitNo TINYINT = 0) RETURNS BIGINT
-- v1.0.0 2006.09.26, Ofer Bester
AS BEGIN
	IF (@BitNo > 63)
		RETURN @BitMap
 
	IF (@BitNo = 63)
		RETURN @BitMap & 0x7FFFFFFFFFFFFFFF
 
	RETURN (@BitMap & ~POWER( CAST(2 AS BIGINT), @BitNo )) -- Set bit # @BitNo OFF
END
GO

-----------------------------------------------------------------------------------
-- Set bigint Bit ON
-----------------------------------------------------------------------------------
IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[fnBitSetOn]') AND xtype in (N'FN', N'IF', N'TF'))
	DROP FUNCTION [dbo].[fnBitSetOn]
Go

CREATE FUNCTION dbo.fnBitSetOn (@BitMap BIGINT, @BitNo TINYINT = 0) RETURNS BIGINT
-- v1.0.0 2006.09.26, Ofer Bester
AS BEGIN
	IF (@BitNo > 63)
		RETURN @BitMap
 
	IF (@BitNo = 63)
		RETURN @BitMap | 0x8000000000000000
 
	RETURN (@BitMap | POWER( CAST(2 AS BIGINT), @BitNo )) -- Set bit # @BitNo ON
END
GO

-----------------------------------------------------------------------------------
-- Toggle bigint Bit ON/OFF
-----------------------------------------------------------------------------------
IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[fnBitToggle]') AND xtype in (N'FN', N'IF', N'TF'))
	DROP FUNCTION [dbo].[fnBitToggle]
Go

CREATE FUNCTION dbo.fnBitToggle (@BitMap BIGINT, @BitNo TINYINT = 0) RETURNS BIGINT
-- v1.0.0 2006.09.26, Ofer Bester
AS BEGIN
	IF ( dbo.fnBitIsOn(@BitMap, @BitNo) = 1 )
		RETURN dbo.fnBitSetOff(@BitMap, @BitNo)

	RETURN dbo.fnBitSetOn(@BitMap, @BitNo)
END



-----------------------------------------------------------------------------------
-- Execute / Usage example script:
-----------------------------------------------------------------------------------
declare @BitMap BIGINT
declare @bitNo TINYINT

set @BitMap = 0
set @bitNo = 55

print '- Bit # = '+CONVERT(VARCHAR,@bitNo)+ ', BitMap value = '+ CONVERT(VARCHAR,@BitMap)
print ' Check bit #'+CONVERT(VARCHAR,@bitNo)
+' - Is bit ON = '+ CONVERT(VARCHAR,dbo.fnBitIsOn(@BitMap, @bitNo))
+', Value ='+ CONVERT(VARCHAR,@BitMap)

set @BitMap = dbo.fnBitSetOn(@BitMap, @bitNo)
print ' Turn bit #'+CONVERT(VARCHAR,@bitNo) +' ON'+
+' - Is bit ON = '+ CONVERT(VARCHAR,dbo.fnBitIsOn(@BitMap, @bitNo))
+', Value ='+ CONVERT(VARCHAR,@BitMap)

set @BitMap = dbo.fnBitSetOff(@BitMap, @bitNo)
print ' Turn bit #'+ CONVERT(VARCHAR,@bitNo) +' OFF'
+' - Is bit ON = '+ CONVERT(VARCHAR,dbo.fnBitIsOn(@BitMap, @bitNo))
+', Value ='+ CONVERT(VARCHAR,@BitMap)

set @BitMap = dbo.fnBitToggle(@BitMap, @bitNo)
print ' Toggle bit #'+ CONVERT(VARCHAR,@bitNo)
+' - Is bit ON = '+ CONVERT(VARCHAR,dbo.fnBitIsOn(@BitMap, @bitNo))
+', Value ='+ CONVERT(VARCHAR,@BitMap)
set @BitMap = dbo.fnBitToggle(@BitMap, @bitNo)
print ' Toggle bit #'+ CONVERT(VARCHAR,@bitNo)
+' - Is bit ON = '+ CONVERT(VARCHAR,dbo.fnBitIsOn(@BitMap, @bitNo))
+', Value ='+ CONVERT(VARCHAR,@BitMap)

print ''
set @BitMap = -1

print '- Bit # = '+CONVERT(VARCHAR,@bitNo)+ ', BitMap value = '+ CONVERT(VARCHAR,@BitMap)
set @BitMap = dbo.fnBitSetOn(@BitMap, @bitNo)
print ' Turn bit #'+CONVERT(VARCHAR,@bitNo) +' ON'+
+' - Is bit ON = '+ CONVERT(VARCHAR,dbo.fnBitIsOn(@BitMap, @bitNo))
+', Value ='+ CONVERT(VARCHAR,@BitMap)

set @BitMap = dbo.fnBitSetOff(@BitMap, @bitNo)
print ' Turn bit #'+ CONVERT(VARCHAR,@bitNo) +' OFF'
+' - Is bit ON = '+ CONVERT(VARCHAR,dbo.fnBitIsOn(@BitMap, @bitNo))
+', Value ='+ CONVERT(VARCHAR,@BitMap)

set @BitMap = dbo.fnBitToggle(@BitMap, @bitNo)
print ' Toggle bit #'+ CONVERT(VARCHAR,@bitNo)
+' - Is bit ON = '+ CONVERT(VARCHAR,dbo.fnBitIsOn(@BitMap, @bitNo))
+', Value ='+ CONVERT(VARCHAR,@BitMap)
set @BitMap = dbo.fnBitToggle(@BitMap, @bitNo)
print ' Toggle bit #'+ CONVERT(VARCHAR,@bitNo)
+' - Is bit ON = '+ CONVERT(VARCHAR,dbo.fnBitIsOn(@BitMap, @bitNo))
+', Value ='+ CONVERT(VARCHAR,@BitMap) 
