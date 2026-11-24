CREATE OR REPLACE PROCEDURE IT.prg_cob_pen_aduana IS
   -- OMM 11/10/2011 Cobro Pendientes de Ticket de Aduana
   v_hor_actual     VARCHAR2(8);
   v_fec_actual     DATE;
   v_nro_secuencia  NUMBER(3) := 0;
   v_nvo_estado     VARCHAR2(1);
   v_sal_disponible NUMBER;
   v_procesa        VARCHAR2(1) := 'N';
   -- movimientos
   r_gmovi ge_movimientos%ROWTYPE;
   --
   v_cod_moneda    ge_cuentas.cod_moneda%TYPE;
   v_cod_oficina   ge_cuentas.cod_oficina%TYPE;
   v_cod_modulo    ge_cuentas.cod_modulo%TYPE;
   v_cod_modalidad ge_cuentas.cod_modalidad%TYPE;
   v_cod_tra_padre ge_transacciones.cod_transaccion%TYPE;
   --v_rub_credito   ge_cuentas.nro_cuenta%TYPE := '0101361105' ; -- Cta de Prueba
   v_rub_credito cb_rubros.cod_rubro%TYPE := '150102570225099'; -- Definido por Alcides Britez
   --v_ofi_cta_cred  ge_cuentas.cod_oficina%TYPE := 1; -- Oficina de la Cta Credito

   CURSOR cuentas IS
      SELECT DISTINCT g.idticket,
                      t.fec_insercion,
                      nvl(b.monto, g.monto) monto,
                      b.cod_per_principal,
                      fue_obt_nom_persona(b.cod_per_principal) nombre,
                      b.nro_cuenta nro_cta_debito
        FROM ge_dna_log g, log_mensajeria_bkp t, bw_movimientos b
       WHERE g.estado = 'P'
         AND g.tipo = 'TCA'
         AND g.tipooperacion = 'T'
         AND ltrim(t.mensaje) LIKE '%' || g.idticket || '%'
         AND substr(t.respuesta, 1, 13) = '0#SIN ERRORES'
         AND TRIM(b.dato) LIKE '%' || g.idticket || '%'
         AND trunc(b.fec_insercion) = trunc(g.fechainserccion)
         AND b.cod_tip_mensaje = '033'
         AND b.cod_respuesta = '000'
       ORDER BY t.fec_insercion;

BEGIN
   v_fec_actual    := pag_cal.fu_obt_fec_actual('4');
   v_hor_actual    := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
   v_cod_tra_padre := 222;
   FOR reg IN cuentas LOOP
      -- Obtiene datos de la cuenta
      SELECT cod_moneda, cod_oficina, cod_modulo, cod_modalidad
        INTO v_cod_moneda, v_cod_oficina, v_cod_modulo, v_cod_modalidad
        FROM ge_cuentas
       WHERE nro_cuenta = reg.nro_cta_debito;
   
      --if v_nro_secuencia > 990 then
      -- Debe ser una HORA para cada cuenta
      v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
      v_nro_secuencia := 0;
      --end if;
   
      IF reg.monto > 0 THEN
         pag_cta.g_cod_error := 0;
         -- verifico si puedo o no cobrar el monto
         pag_cta.pr_ver_operacion(reg.nro_cta_debito, v_cod_tra_padre,
                                  -- padre
                                  9, 91, 'D',
                                  -- TIPO DEBITO
                                  v_cod_moneda, reg.monto, v_cod_oficina, v_cod_modulo,
                                  v_cod_modalidad, v_nvo_estado, v_sal_disponible, v_procesa, 503);
         IF v_procesa = 'S' AND pag_cta.g_cod_error = 0 THEN
            -- no se puede debitar y queda como pendiente
            pag_cta.pr_act_operacion(reg.nro_cta_debito, v_hor_actual, 'D',
                                     -- debito a la cuenta del cliente
                                     v_cod_moneda, reg.monto, v_cod_tra_padre, 503,
                                     -- trans. hijo
                                     reg.nro_cta_debito,
                                     -- Nro de Documento
                                     NULL,
                                     -- cotizacion
                                     v_cod_oficina, 9, 91, NULL,
                                     -- tasa
                                     NULL,
                                     -- valor de tasa
                                     'Débito DNA-Ticket: ' || reg.idticket,
                                     --concepto
                                     'N',
                                     -- emitir aviso
                                     v_nro_secuencia,
                                     -- nro de secuencia
                                     v_fec_actual);
         
            IF nvl(pag_cta.g_cod_error, 0) = 0 THEN
               -- Realiza el Credito a la cuenta indicada
               -- movimiento puede ser ingresado
               r_gmovi.cod_modulo    := 2;
               r_gmovi.cod_modalidad := 21;
               r_gmovi.cod_oficina   := 31; --v_cod_oficina  ; Siempre tiene que ser Central.
               r_gmovi.cod_rubro     := v_rub_credito;
               r_gmovi.cod_moneda    := v_cod_moneda;
               r_gmovi.cod_usuario   := USER;
               r_gmovi.hora          := v_hor_actual;
               r_gmovi.fecha         := v_fec_actual;
               -- Aumento la secuencia
               v_nro_secuencia       := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia := v_nro_secuencia;
               --
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := v_cod_tra_padre;
               r_gmovi.cod_mod_padre   := 9;
               r_gmovi.cod_mad_padre   := 91;
               r_gmovi.cod_transaccion := 741;
               r_gmovi.monto           := reg.monto;
               r_gmovi.nro_documento   := reg.nro_cta_debito;
               r_gmovi.cod_ofi_origen  := v_cod_oficina; --31;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := 'CRE-DNA-Ticket: ' || reg.idticket;
               r_gmovi.estado          := 'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.tip_mov_rubro   := 'C';
               pag_gen.pr_ins_ge_movimiento(r_gmovi);
            
               /*Se comento para utilizar rubro para el crédito
                    pag_cta.pr_act_operacion(v_cta_credito,
                                       v_hor_actual,
                                       'C', -- debito a la cuenta del cliente
                                       v_cod_moneda,
                                       reg.monto,
                                       v_cod_tra_padre,
                                       602, -- trans. hijo
                                       reg.nro_cta_debito, -- Nro de Documento
                                       null, -- cotizacion
                                       v_ofi_cta_cred, -- Oficina de la Cta Credito
                                       9,
                                       91,
                                       null, -- tasa
                                       null, -- valor de tasa
                                       'DNA-Ticket: '||reg.idticket , --concepto
                                       'N', -- emitir aviso
                                       v_nro_secuencia, -- nro de secuencia
                                       v_fec_actual);
               */
            
               UPDATE ge_dna_log d
                  SET d.estado     = 'F',
                      d.msgerror   = 'DÉBITO MANUAL',
                      d.nro_cuenta = reg.nro_cta_debito
                WHERE d.idticket = reg.idticket
                  AND d.estado = 'P'
                  AND d.tipo = 'TCA'
                  AND d.tipooperacion = 'T';
               IF SQL%NOTFOUND THEN
                  raise_application_error(-20000,
                                          'Error Act.GE_DNA_LOG:' || 'idticket=' || reg.idticket);
               END IF;
            END IF;
         END IF;
      END IF;
   END LOOP;
END prg_cob_pen_aduana;
/

