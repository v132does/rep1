CREATE OR REPLACE PROCEDURE IT.prj_ver_mto_valores
(
   p_cod_valor  IN NUMBER,
   p_monto      IN NUMBER,
   p_mto_valido OUT VARCHAR2,
   p_cantidad   OUT NUMBER,
   p_mensaje    OUT VARCHAR2
) IS
   v_descripcion cj_tip_valores.descripcion%TYPE;
   v_cod_moneda  cj_tip_valores.cod_moneda%TYPE;
   v_valor       cj_tip_valores.valor%TYPE;
   v_tipo        cj_tip_valores.tipo%TYPE;
   v_for_total   cj_tip_valores.for_total%TYPE;
   v_cantidad    NUMBER;
BEGIN
   --Traer los Parametros del Valor--
   prj_obt_dat_valores(p_cod_valor, v_descripcion, v_cod_moneda, v_valor, v_tipo, v_for_total);
   --Verificacion de Montos--
   IF v_for_total = 'C' THEN
      --C-Cantidad--
      v_cantidad := p_monto / v_valor;
      IF v_cantidad <> trunc(v_cantidad) THEN
         p_mto_valido := 'N';
         p_cantidad   := NULL;
         p_mensaje    := 'Monto no Valido, Verifique';
      ELSE
         p_mto_valido := 'S';
         p_cantidad   := v_cantidad;
         p_mensaje    := NULL;
      END IF;
   ELSE
      --M-Monto--
      p_mto_valido := 'S';
      p_cantidad   := NULL;
      p_mensaje    := NULL;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en PRJ_VER_MTO_VALORES: ' || SQLERRM);
END prj_ver_mto_valores;
/

