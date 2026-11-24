CREATE OR REPLACE FUNCTION IT.fup_obt_mto_apl_reversar
(
   p_nro_cuenta   IN VARCHAR2,
   p_cod_garantia NUMBER,
   p_nro_garantia NUMBER,
   p_fecha        IN DATE,
   p_hora         IN VARCHAR2,
   p_cod_usuario  IN VARCHAR2
) RETURN NUMBER IS
   --Obs: creado por rpavon en Bco. Regional 04/10/2007--
   --Obtiene el monto a reversar de la garantia--
   --segun sus registros de novedades--
   v_mto_apl_reversar NUMBER(18, 2) := 0;

BEGIN
   --Obtener el monto a reversar--
   SELECT SUM(a.mto_aplicado - a.mto_apl_modificado)
     INTO v_mto_apl_reversar
     FROM pr_cta_garantias_nov a
    WHERE a.fecha = p_fecha
      AND a.hora = p_hora
      AND a.cod_usuario = p_cod_usuario
      AND a.nro_cuenta = p_nro_cuenta
      AND a.cod_garantia = p_cod_garantia
      AND nvl(a.nro_garantia, 999) = nvl(p_nro_garantia, 999);
   RETURN v_mto_apl_reversar;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en fup_obt_mto_apl_reversar : ' || SQLERRM);
END;
/

