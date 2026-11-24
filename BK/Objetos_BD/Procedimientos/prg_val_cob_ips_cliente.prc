CREATE OR REPLACE PROCEDURE IT.PRG_VAL_COB_IPS_CLIENTE(p_cod_persona in ba_personas.cod_persona%type,                                                   
                                                       p_mensaje out varchar2) is

v_cant_persona NUMBER(1) := 0;
v_cod_ente ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('COD_ENT_IPS'));
BEGIN
 
 BEGIN
  --Contiene datos de los Ahorros a la Vista.
SELECT COUNT(*)
   INTO v_cant_persona
  FROM ah_cta_vistas ah, ge_cta_clientes cl, ba_personas pp
 WHERE ah.cod_ente = v_cod_ente --IPS
   AND ah.cod_modulo = cl.cod_modulo
   AND ah.cod_modalidad = cl.cod_modalidad
   AND ah.nro_cuenta = cl.nro_cuenta   
   AND cl.cod_persona = pp.cod_persona
   AND pp.cod_persona = p_cod_persona;
EXCEPTION
  WHEN OTHERS THEN
    p_mensaje:='NO';   
END;
IF v_cant_persona > 0 THEN
    p_mensaje :='SI';
END IF;
IF v_cant_persona = 0 THEN
    p_mensaje := 'NO';
END IF; 

END;
/
