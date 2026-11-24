CREATE OR REPLACE PROCEDURE IT.prj_obt_dat_valores
(
   p_cod_valor   IN NUMBER,
   p_descripcion OUT VARCHAR2,
   p_cod_moneda  OUT VARCHAR2,
   p_valor       OUT NUMBER,
   p_tipo        OUT VARCHAR2,
   p_for_total   OUT VARCHAR2
) IS
BEGIN
   SELECT descripcion, cod_moneda, valor, tipo, for_total
     INTO p_descripcion, p_cod_moneda, p_valor, p_tipo, p_for_total
     FROM cj_tip_valores x
    WHERE x.cod_tip_valor = p_cod_valor;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en PRJ_OBT_DAT_VALORES: ' || SQLERRM);
END prj_obt_dat_valores;
/

