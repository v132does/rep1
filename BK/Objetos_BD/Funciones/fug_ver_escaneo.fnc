CREATE OR REPLACE FUNCTION IT.FUG_VER_ESCANEO
 (P_NRO_CUENTA IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
-- devuelve si tiene o no firma escaneada
v_sin_escaneo number := 0;
begin
/*
   select sum(decode(b.cl_nmarchi,null,1,0))
     into v_sin_escaneo
     from ba_personas c,firmas.frclient b, ge_cta_clientes a 
    where a.nro_cuenta = p_nro_cuenta
      and c.cod_persona = a.cod_persona
      and c.tipo = 'F' -- solo firmantes fisicos
      and b.cl_cdclien = a.cod_persona;
      */
   if v_sin_escaneo > 0 then
      return 'N';
   else   
      return 'S';
   end if;   
EXCEPTION
   WHEN NO_DATA_FOUND  THEN
      return 'N';
end;
/

