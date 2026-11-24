CREATE OR REPLACE FUNCTION IT.FUG_CTA_FORMATEADA
 (P_COD_MODULO 		   IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD 	 IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA   	 IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA    	 IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA     	 IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_DIG_VERIFICADOR  IN GE_CUENTAS.DIG_VERIFICADOR%TYPE DEFAULT 0)
 RETURN VARCHAR2
 IS
v_sub_aplic 	 	  	varchar2(02);
v_cod_modulo			  ge_cuentas.cod_modulo%TYPE;
v_cod_modalidad		  ge_cuentas.cod_modalidad%TYPE;
v_cod_oficina			  ge_cuentas.cod_oficina%TYPE;
v_cod_moneda			  ge_cuentas.cod_moneda%TYPE;
v_longitud          number(5) := 7;
BEGIN
  return p_nro_cuenta;
  
	IF p_cod_modulo IS NULL THEN
   	SELECT cod_modulo, cod_modalidad, cod_oficina, cod_moneda
		INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda
		FROM ge_cuentas
		WHERE nro_cuenta = p_nro_cuenta; 

      IF v_cod_modalidad = 31 THEN
         SELECT decode(v_cod_moneda,pag_gen.fu_obt_mon_local,'01',pag_gen.fu_obt_mon_fuerte,'02','99')
         INTO v_sub_aplic
         FROM DUAL;
      ELSIF v_cod_modulo = 4 THEN
         SELECT decode(v_cod_moneda,pag_gen.fu_obt_mon_local,'10',pag_gen.fu_obt_mon_fuerte,'11')
         INTO v_sub_aplic
         FROM DUAL;
      ELSIF v_cod_modalidad = 33 THEN
         SELECT decode(v_cod_moneda,pag_gen.fu_obt_mon_local,'04',pag_gen.fu_obt_mon_fuerte,'06')
         INTO v_sub_aplic
         FROM DUAL;
      END IF;
      IF v_cod_modulo = 6 THEN
         -- El numero de cuenta de prestamo se debe mostrar como es para no crear problemas en
         -- el homebanking y en el autoservicio.      
/*         if length(p_nro_cuenta) > 7 then
           RETURN substr(p_nro_cuenta,1,2)||' '||
                  substr(p_nro_cuenta,3,2)||' '||
                  substr(p_nro_cuenta,5);
         else*/
           RETURN p_nro_cuenta;
        -- end if;    
      Elsif v_cod_modulo = 5 then
         return p_nro_cuenta;     
      ELSE
         if length(p_nro_cuenta) > v_longitud then
            v_longitud := length(p_nro_cuenta);
         End if;
         RETURN ltrim(to_char(v_cod_oficina,'00'))||' '||
             v_sub_aplic||' '||
             lpad(p_nro_cuenta,v_longitud,'0');
      END IF;
				
	ELSE
      IF p_cod_modalidad = 31 THEN
         SELECT decode(p_cod_moneda,pag_gen.fu_obt_mon_local,'01',pag_gen.fu_obt_mon_fuerte,'02','99')
         INTO v_sub_aplic
         FROM DUAL;
      ELSIF p_cod_modulo = 4 THEN
         SELECT decode(p_cod_moneda,pag_gen.fu_obt_mon_local,'10',pag_gen.fu_obt_mon_fuerte,'11')
         INTO v_sub_aplic
         FROM DUAL;
      ELSIF p_cod_modalidad = 33 THEN
         SELECT decode(p_cod_moneda,pag_gen.fu_obt_mon_local,'04',pag_gen.fu_obt_mon_fuerte,'06')
         INTO v_sub_aplic
         FROM DUAL;
      END IF;
      IF p_cod_modulo = 6 THEN
         -- El numero de cuenta de prestamo se debe mostrar como es para no crear problemas en
         -- el homebanking y en el autoservicio.
         
         /*if length(p_nro_cuenta) > 7 then
           RETURN substr(p_nro_cuenta,1,2)||' '||
                  substr(p_nro_cuenta,3,2)||' '||
                  substr(p_nro_cuenta,5);
         else*/
           RETURN p_nro_cuenta;
         --end if;  
      Elsif v_cod_modulo = 5 then
         return p_nro_cuenta;               
      ELSE
         if length(p_nro_cuenta) > v_longitud then
            v_longitud := length(p_nro_cuenta);
         End if;      
         RETURN ltrim(to_char(p_cod_oficina,'00'))||' '||
             v_sub_aplic||' '||
             lpad(p_nro_cuenta,v_longitud,'0');
      END IF;
	END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,
      'fug_cta_formateada-> Mod: '||to_char(p_cod_modulo)||
      ' Modal: '||to_char(p_cod_modalidad)||
      ' Ofic: '||to_char(p_cod_oficina)||
      ' Cta: '||p_nro_cuenta||
      ' Mon: '||p_cod_moneda);
END;
/

