CREATE OR REPLACE FUNCTION IT.fus_obt_cta_operacion
(
   p_nro_operacion IN sb_crc_operaciones_det.nro_operacion%TYPE,
   p_cod_modulo    sb_crc_operaciones_det.cod_modulo%TYPE
) RETURN VARCHAR2 IS
   v_nro_cuenta sb_crc_operaciones_det.nro_operacion%TYPE;
BEGIN
   IF /*p_cod_modulo = 3 THEN
      --Serie+”–“+ número de cartón +moneda
      BEGIN
         SELECT nro_cuenta
           INTO v_nro_cuenta
           FROM ah_cta_certificados
          WHERE serie = substr(p_nro_operacion, 1, 2)
            AND nro_certificado = substr(p_nro_operacion, 4,6)
            AND cod_moneda = decode(substr(p_nro_operacion, -1, 4), 0001, 'USD', 'GS');

      EXCEPTION
         WHEN no_data_found THEN
            v_nro_cuenta := p_nro_operacion;
         WHEN OTHERS THEN
            v_nro_cuenta := p_nro_operacion;
      END;
   ELSIF*/ p_cod_modulo = 5 THEN
      BEGIN
         SELECT DISTINCT s.nro_cuenta
           INTO v_nro_cuenta
           FROM ta_tarjetas s, ge_cta_clientes p
          WHERE p.nro_cuenta = s.nro_cuenta
            AND s.nro_tarjeta = p_nro_operacion;
      EXCEPTION
         WHEN no_data_found THEN
            v_nro_cuenta := p_nro_operacion;
         WHEN OTHERS THEN
            v_nro_cuenta := p_nro_operacion;
      END;
   ELSIF p_cod_modulo = 6 THEN
      BEGIN
         v_nro_cuenta := pae_uti.fu_obt_valor(p_nro_operacion, 1);
      EXCEPTION
         WHEN no_data_found THEN
            v_nro_cuenta := p_nro_operacion;
         WHEN OTHERS THEN
            v_nro_cuenta := p_nro_operacion;
      END;
   ELSE
      v_nro_cuenta := p_nro_operacion;
   END IF;

   RETURN v_nro_cuenta;
END;
/

