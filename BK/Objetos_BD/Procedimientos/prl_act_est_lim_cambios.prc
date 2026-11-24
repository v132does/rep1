CREATE OR REPLACE PROCEDURE IT.prl_act_est_lim_cambios
(
   p_nro_cuenta IN lc_cta_cambios.nro_cuenta%TYPE DEFAULT NULL,
   p_est_cuenta IN lc_cta_cambios.estado%TYPE DEFAULT NULL
) IS
   -- lcabrera - 09-Nov-2015
   /* Proceso para actualización de Estados de límites de Cambio.
   Se podrá ejecutar para una cuenta o en proceso de Inicio/ Cierre de día
   a fin de Pasar a Vencido las Cuentas cuya fecha de Vencimiento sean menor o igual a la fecha actual*/

   CURSOR c_cta_cambios IS
      SELECT c.nro_cuenta, c.estado, c.fec_vencimiento
        FROM lc_cta_cambios c
       WHERE ((p_nro_cuenta IS NOT NULL AND c.nro_cuenta = p_nro_cuenta) OR (p_nro_cuenta IS NULL))
         AND c.fec_vencimiento <= pae_cnf.fu_obt_fec_actual(7)
         AND c.estado NOT IN ('V', 'C'); -- Vencidos - Cancelados

   v_estado lc_cta_cambios.estado%TYPE;

BEGIN

   FOR c_cam IN c_cta_cambios LOOP
      IF p_nro_cuenta IS NULL THEN
         v_estado := 'V';
      ELSE
         v_estado := p_est_cuenta;
      END IF;

      BEGIN
         UPDATE lc_cta_cambios SET estado = v_estado WHERE nro_cuenta = c_cam.nro_cuenta;

         IF SQL%NOTFOUND THEN
            raise_application_error(-20000,
                                    'No existe dato en Cta. Cambios, Nro.:  ' || p_nro_cuenta);
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20001,
                                    'Al Actualizar Estado de Cta. Cambios, Nro.: ' || p_nro_cuenta);
      END;
   END LOOP;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,
                              'ERROR. PRL_ACT_EST_LIM_CAMBIOS - ' || p_nro_cuenta || ' ESTADO: ' ||
                               p_est_cuenta || SQLERRM);
END;
/

