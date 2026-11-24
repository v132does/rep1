CREATE OR REPLACE FUNCTION IT.FUG_OBT_RELACION
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS

V_ESCLTE VARCHAR2(1);
V_RELACION VARCHAR2(1);
V_EXISTE VARCHAR2(1);
-- Retorna la relacion de la persona con el banco
  -- Si posee cuentas activas y es principal en ellas: es un cliente
  -- Si posee cuentas activas pero no es principal en ninguna de ellas: es firmante
  -- Si no: es persona
BEGIN
  v_esclte  := 'N';
  v_relacion := 'P'; -- por defecto es persona
  v_existe := 'S';
  Begin
	 	 Select 'S'
	 	   into v_existe
	 	   from GE_EST_CUENTAS EC, GE_CUENTAS GC, GE_CTA_CLIENTES GCTA
	 	  where GC.NRO_CUENTA = GCTA.NRO_CUENTA
	 	    and GCTA.RELACION = 'P'
 	 	    and GCTA.COD_PERSONA = P_COD_PERSONA
        and GC.ESTADO = EC.ESTADO
        and GC.COD_MODULO = EC.COD_MODULO
        AND GC.COD_MODALIDAD = EC.COD_MODALIDAD
        AND EC.ACTIVO = 'S';
 	 	 RAISE TOO_MANY_ROWS;
  Exception
    	 When NO_DATA_FOUND Then
    	      v_existe   := 'N';
     	      v_relacion := 'P';
     	 When TOO_MANY_ROWS Then
     	      v_existe   := 'S';
    	      v_relacion := 'C';
  End;
  If v_existe = 'N' Then
     Begin
  	 	 Select 'S'
  	 	   into v_existe
  	 	   from GE_EST_CUENTAS EC,GE_CUENTAS GC, GE_CTA_CLIENTES GCTA
  	 	  where GC.NRO_CUENTA = GCTA.NRO_CUENTA
  	 	    and RELACION != 'P'
          and COD_PERSONA = P_COD_PERSONA
          and GC.ESTADO = EC.ESTADO
  	 	    and GC.COD_MODULO = EC.COD_MODULO
          and GC.COD_MODALIDAD = EC.COD_MODALIDAD
          and EC.ACTIVO = 'S';
  	 	 Raise TOO_MANY_ROWS;
     Exception
     	 When NO_DATA_FOUND Then
     	      v_existe   := 'N';
     	      v_relacion := 'P';
     	 When TOO_MANY_ROWS Then
     	      v_existe   := 'S';
     	      v_relacion := 'F';
  	 End;
  End If;
  Return v_relacion;
END;
/

