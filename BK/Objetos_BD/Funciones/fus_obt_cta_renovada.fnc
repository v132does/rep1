CREATE OR REPLACE FUNCTION IT.fus_obt_cta_renovada
(
   p_nro_operacion IN sb_crc_operaciones_det.nro_operacion%TYPE,
   p_cod_modulo    IN ba_modulos.cod_modulo%TYPE
) RETURN VARCHAR2 IS
   v_nro_cuenta sb_crc_operaciones_det.nro_operacion%TYPE;
BEGIN
   IF p_nro_operacion LIKE ('%##%') THEN
      --Serie+”–“+ número de cartón +moneda
      BEGIN
         SELECT nro_cta_renovada
           INTO v_nro_cuenta
           FROM pr_cobros_rrr
          WHERE nro_cuenta = pae_uti.fu_obt_valor(p_nro_operacion, 1);
      EXCEPTION
         WHEN no_data_found THEN
            v_nro_cuenta := p_nro_operacion;
         WHEN OTHERS THEN
            v_nro_cuenta := p_nro_operacion;
      END;
   ELSE
      v_nro_cuenta := fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo);
   END IF;

   RETURN v_nro_cuenta;
END;
/

