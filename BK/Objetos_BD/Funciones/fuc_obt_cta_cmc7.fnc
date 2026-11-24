CREATE OR REPLACE FUNCTION IT.FUC_OBT_CTA_CMC7
 (p_nro_cuenta in varchar2
 )
 return varchar2
 is
 v_nro_cuenta  ge_cuentas.nro_cuenta%type;
 v_nro_cta_ori ge_cuentas.nro_cuenta%type;
begin
   if substr(p_nro_cuenta,1,2) = '00' then -- corresponde al formato nuevo.
     v_nro_cuenta := substr(p_nro_cuenta,3,10);
   else
     v_nro_cuenta := substr(p_nro_cuenta,1,2)||substr(p_nro_cuenta,5,8);
     BEGIN
       SELECT nro_cuenta
         INTO v_nro_cta_ori
         FROM ge_cuentas
        WHERE cod_modulo = 4
          AND to_number(nro_cuenta) = rtrim(p_nro_cuenta);
     EXCEPTION
       WHEN OTHERS THEN
         v_nro_cta_ori := NULL;
     END;
     IF v_nro_cta_ori IS NOT NULL THEN
        v_nro_cuenta := v_nro_cta_ori;
     END IF;
   end if;
   
   return v_nro_cuenta;

end;
/

