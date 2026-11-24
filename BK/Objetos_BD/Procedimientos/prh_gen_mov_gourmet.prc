CREATE OR REPLACE PROCEDURE IT.prh_gen_mov_gourmet IS
   -- RABF 28/11/2011 Genera movimientos para Acreditación de la Gourmet Card
   -- la acreditación se hace realmente en la procesadora, esto es para dejar
   -- registro del movimiento nomás. La transacción en cuestión no debe afectar Saldo.
   v_hor_actual    VARCHAR2(8) := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
   v_fec_actual    DATE := pag_cal.fu_obt_fec_actual(5);
   v_nro_secuencia NUMBER(3) := 0;
   -- movimientos
   r_gmovi ge_movimientos%ROWTYPE;
   --
   v_cod_moneda      ge_cuentas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_cod_modulo      ge_cuentas.cod_modulo%TYPE := 5;
   v_cod_modalidad   ge_cuentas.cod_modalidad%TYPE := 55;
   v_cod_tra_padre   ge_transacciones.cod_transaccion%TYPE := 250;
   v_cod_transaccion ge_transacciones.cod_transaccion%TYPE := 699;

   CURSOR cuentas IS
      SELECT t.nro_cuenta,
             a.monto,
             a.cod_moneda,
             a.nro_documento,
             t.nro_tarjeta,
             a.cod_ofi_origen,
             a.cod_oficina
        FROM ge_movimientos a, ta_tarjetas t
       WHERE a.cod_transaccion = 1419
         AND a.cod_modulo = 14
         AND a.cod_modalidad = 141
         AND a.cod_tra_padre = 1303
         AND a.referencia IS NOT NULL
         AND TRIM(a.referencia) = TRIM(t.nro_tarjeta)
         AND NOT EXISTS (SELECT 1
                FROM ge_movimientos g
               WHERE g.cod_tra_padre = 250
                 AND g.cod_transaccion = 699
                 AND g.cod_modalidad = 55
                 AND g.nro_cuenta = t.nro_cuenta
                 AND g.monto = a.monto);

BEGIN
   FOR reg IN cuentas LOOP
      IF reg.monto > 0 THEN
         --- Recuperar datos de la cuenta
         pag_cta.pr_obt_cuenta(reg.nro_cuenta);
         IF pag_cta.fu_obt_cod_error() <> 0 THEN
            raise_application_error(-20000, 'Error Obt.Cta.:' || pag_cta.fu_obt_msj_error());
         END IF;
         -- Realiza el Credito a la cuenta indicada
         -- movimiento puede ser ingresado
         r_gmovi.cod_modulo    := v_cod_modulo;
         r_gmovi.cod_modalidad := v_cod_modalidad;
         --r_gmovi.cod_oficina   := reg.cod_oficina; -- RABF 14/12/2011
         r_gmovi.cod_oficina := pag_cta.g_ctas.cod_oficina; -- oficina de origen debe ser de la cuenta
         r_gmovi.cod_rubro   := NULL;
         r_gmovi.cod_moneda  := v_cod_moneda;
         r_gmovi.cod_usuario := USER;
         r_gmovi.hora        := v_hor_actual;
         r_gmovi.fecha       := v_fec_actual;
         -- Aumento la secuencia
         v_nro_secuencia       := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia := v_nro_secuencia;
         --
         r_gmovi.fec_valor       := v_fec_actual;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
         r_gmovi.cod_mod_padre   := v_cod_modulo;
         r_gmovi.cod_mad_padre   := v_cod_modalidad;
         r_gmovi.cod_transaccion := v_cod_transaccion;
         r_gmovi.monto           := reg.monto;
         r_gmovi.nro_cuenta      := reg.nro_cuenta;
         r_gmovi.nro_documento   := reg.nro_documento;
         r_gmovi.referencia      := reg.nro_tarjeta;
         r_gmovi.cod_ofi_origen  := reg.cod_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         -- solo 35 caracteres para enviar en descripcion a Bancard
         r_gmovi.concepto      := substr('Cred.Gourmet Card:' || reg.nro_tarjeta, 1, 35);
         r_gmovi.estado        := 'N';
         r_gmovi.reversado     := 'N';
         r_gmovi.tip_mov_rubro := NULL;
         pag_gen.pr_ins_ge_movimiento(r_gmovi);
      END IF;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'Error en Mov.Acreditación Gourmet.' || SQLERRM);
      END IF;
END prh_gen_mov_gourmet;
/

