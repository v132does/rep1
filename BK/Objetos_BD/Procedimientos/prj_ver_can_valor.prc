CREATE OR REPLACE PROCEDURE IT.prj_ver_can_valor
(
   p_cod_valor  IN NUMBER,
   p_cantidad   IN NUMBER,
   p_mto_valido OUT VARCHAR2,
   p_monto      OUT NUMBER,
   p_mensaje    OUT VARCHAR2
) IS
   v_descripcion cj_tip_valores.descripcion%TYPE;
   v_cod_moneda  cj_tip_valores.cod_moneda%TYPE;
   v_valor       cj_tip_valores.valor%TYPE;
   v_tipo        cj_tip_valores.tipo%TYPE;
   v_for_total   cj_tip_valores.for_total%TYPE;
BEGIN
   --Traer los Parametros del Valor--
   prj_obt_dat_valores(p_cod_valor, v_descripcion, v_cod_moneda, v_valor, v_tipo, v_for_total);
   p_monto      := p_cantidad * v_valor;
   p_mto_valido := 'S';
   p_mensaje    := NULL;
EXCEPTION
   WHEN OTHERS THEN
      p_mto_valido := 'N';
      p_monto      := NULL;
      raise_application_error(-20000, 'Error en PRJ_VER_CANT_VALORES: ' || SQLERRM);
END prj_ver_can_valor;
/

