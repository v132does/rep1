CREATE OR REPLACE PROCEDURE IT."PRG_DEB_AUT_AS400" IS
--cursor ge_bloqueos
         CURSOR c_ge_bloqueados IS SELECT * FROM ge_bloqueos ge WHERE ge.cod_causa=251;
         c_datos_cursor  c_ge_bloqueados%ROWTYPE;

         v_fec_actual date:=pag_cal.FU_OBT_FEC_ACTUAL(1);
--cursor simgia_debcreit - tabla de debitos
         cursor c_deuda_pendientes IS select * from vsimgia_debcreit mdp order by nro_cuenta;
--variales
v_cod_transaccion number(4);
v_cod_mod_padre   number(3);
v_cod_mad_padre   number(3);
v_cod_modulo      number(3);
v_cod_moneda ba_monedas.cod_moneda%type;
v_cod_oficina ba_oficinas.cod_oficina%type;
v_error VARCHAR2(2000);
PROCEDURE LP_INS_MOV_ERROR;
c_datos_deuda c_deuda_pendientes%rowtype;
r_gmovi          ge_movimientos%rowtype;
v_hora ge_bloqueos.hor_inicio%TYPE:=to_char(SYSDATE,'HH24:MI:SS');
v_nro_secuencia number(3) := -999;
v_cod_modalidad number(3);
v_band_error number(1) := 0;
--procecimiento Graba mov. con error
PROCEDURE LP_INS_MOV_ERROR
IS
BEGIN
   --- Cargar registro de movimientos
  v_hora                           := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
  r_gmovi.cod_usuario              :=USER;
  r_gmovi.hora                     :=v_hora;
  r_gmovi.nro_secuencia            :=v_nro_secuencia;
  r_gmovi.cod_modulo               :=v_cod_modulo;
  r_gmovi.cod_modalidad            :=v_cod_modalidad;
  r_gmovi.cod_oficina              :=v_cod_oficina;
  r_gmovi.nro_cuenta               :=c_datos_deuda.nro_cuenta;
  r_gmovi.cod_moneda               :=v_cod_moneda;
  r_gmovi.cod_tra_padre            :=v_cod_transaccion;
  r_gmovi.cod_transaccion          :=v_cod_transaccion;
  r_gmovi.fecha                    :=v_fec_actual;
  r_gmovi.fec_valor                :=v_fec_actual;
  r_gmovi.nro_documento            :=NULL;
  r_gmovi.monto                    :=c_datos_deuda.mto_deuda;
  r_gmovi.cod_autorizacion         :=NULL;
  r_gmovi.cod_usu_autorizador      :=USER;
  r_gmovi.cod_error                :=pag_cta.G_COD_ERROR;
  r_gmovi.cod_retencion            :=NULL;
  r_gmovi.fec_fin_retencion        :=NULL;
  r_gmovi.est_cuenta               :='E';
  r_gmovi.nro_documento2           :=NULL;
  r_gmovi.nro_documento3           :=NULL;
  r_gmovi.estado                   :='E';
  r_gmovi.cod_causa                :=NULL;
  r_gmovi.cod_banco                :=NULL;
  r_gmovi.cod_ofi_origen           :=v_cod_oficina;
  r_gmovi.cod_bco_central          :=NULL;
  r_gmovi.concepto                 :=c_datos_deuda.itref;
  r_gmovi.cod_tip_ope_cambio       :=NULL;
  r_gmovi.cod_tasa                 :=NULL;
  r_gmovi.val_tasa                 :=NULL;
  r_gmovi.reversado                :='N';
  r_gmovi.cod_usu_reversion        :=NULL;
  r_gmovi.hor_reversion            :=NULL;
  r_gmovi.emi_aviso                :='N';
  r_gmovi.protegido                :='N';
  r_gmovi.cod_mod_padre            :=v_cod_mod_padre;
  r_gmovi.cod_mad_padre            :=v_cod_mad_padre;
  r_gmovi.tip_mov_rubro            :=NULL;
  r_gmovi.cod_rubro                :=NULL;
  r_gmovi.nro_documento4           :=NULL;
  r_gmovi.nro_caja                 :=NULL;
  r_gmovi.cod_ref_cambio           :=NULL;
  r_gmovi.referencia               :=NULL;
  r_gmovi.cod_persona              :=c_datos_deuda.cod_persona;
  r_gmovi.cod_sit_contable         :=NULL;
  pag_gen.pr_ins_ge_movimiento(r_gmovi);
END;
--
begin
  BEGIN
       OPEN c_ge_bloqueados;
       LOOP
       FETCH c_ge_bloqueados INTO c_datos_cursor;
           IF c_ge_bloqueados%FOUND THEN
                --obtencion cuentas y conf
                BEGIN
                    pag_cta.PR_OBT_CUENTA(c_datos_cursor.nro_cuenta);
                    if pag_cta.G_COD_ERROR <> 0 then
                       RAISE_APPLICATION_ERROR(-20000,'Error:'||pag_cta.G_MSJ_ERROR);
                    end if;
                    pag_cta.PR_ACT_SAL_CTA(
                                        c_datos_cursor.nro_cuenta,
                                        pag_cta.G_CTAS.cod_modalidad,
                                        'C',
                                        v_fec_actual,
                                        v_hora,
                                        0,
                                        0,
                                        c_datos_cursor.monto * -1,
                                        'N',
                                        'N');
                   IF pag_cta.G_COD_ERROR <> 0 THEN
                      RAISE_APPLICATION_ERROR(-20000,'Error:'||pag_cta.G_MSJ_ERROR);
                   END IF;
                   --eliminamos registro en la tabla ge_bloqueos
                   --pk->nro_cuenta,fec_inicio,nro_documento
                   DELETE FROM ge_bloqueos WHERE
                          nro_cuenta = c_datos_cursor.nro_cuenta
                          AND fec_inicio = c_datos_cursor.fec_inicio
                          AND nro_documento = c_datos_cursor.nro_documento;
               END;
           END IF;
       EXIT WHEN c_ge_bloqueados%NOTFOUND;
       END LOOP;
  EXCEPTION
  WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'Error:'||sqlerrm);
  END;
  --LECTURA DE LOS CREDITOS/DEBITOS POR FECHA DE PROCESO DE ACTUALIZACION
  BEGIN
       --procesar datos de tabla simgia_debcreit de debitos del AS/400;
       OPEN c_deuda_pendientes;
       LOOP
            FETCH c_deuda_pendientes INTO c_datos_deuda;
                  v_band_error := 0;
                  IF c_deuda_pendientes%FOUND THEN
                      IF v_nro_secuencia > 990 then
                         v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
                         v_nro_secuencia := -999;
                      END IF;
                      --prodec.
                      IF c_datos_deuda.ittipo = 'C' then
                         v_cod_transaccion := 3602;
                         v_cod_mod_padre   := 3;
                         v_cod_mad_padre   := 31;
                      ELSE
                         v_cod_transaccion := 3503;
                         v_cod_mod_padre   := 3;
                         v_cod_mad_padre   := 31;
                      END IF;
                      v_nro_secuencia:=v_nro_secuencia + 1;
                      pag_cta.PR_OBT_CUENTA(c_datos_deuda.nro_cuenta);
                      v_cod_moneda := pag_cta.G_CTAS.cod_moneda;
                      v_cod_oficina := pag_cta.G_CTAS.cod_oficina;
                      v_cod_modulo := pag_cta.G_CTAS.cod_modulo;
                      v_cod_modalidad :=pag_cta.G_CTAS.cod_modalidad;


                      IF pag_cta.G_COD_ERROR <> 0 THEN
                         v_band_error := 1;
                         v_error:='Error:'||pag_cta.G_MSJ_ERROR;
                         UPDATE simgia_debcreit SET respuesta=v_error,estado=9 WHERE nro_cuenta=c_datos_deuda.nro_cuenta and itref = c_datos_deuda.itref and cod_persona = c_datos_deuda.cod_persona and itmonto = c_datos_deuda.mto_deuda;
                         LP_INS_MOV_ERROR;
                         --RAISE_APPLICATION_ERROR(-20000,'Error:'||pag_cta.G_MSJ_ERROR);
                      END IF;
                      pag_cta.PR_ACT_OPERACION(c_datos_deuda.nro_cuenta,
                                                  v_hora,
                                                  c_datos_deuda.ittipo,
                                                  v_cod_moneda,
                                                  nvl(c_datos_deuda.mto_deuda,0),
                                                  v_cod_transaccion,
                                                  v_cod_transaccion,
                                                  to_number(c_datos_deuda.cod_persona),
                                                  NULL,
                                                  pag_cta.g_ctas.cod_oficina,
                                                  v_cod_mod_padre,
                                                  v_cod_mad_padre,
                                                  NULL,
                                                  NULL,
                                                  substr(c_datos_deuda.itref,1,100),
                                                  'S',
                                                  v_nro_secuencia,
                                                  v_fec_actual);
                      IF pag_cta.G_COD_ERROR <> 0 OR pag_cta.G_OK_PROCESAR='N' THEN
                         v_band_error := 1;
                         v_error:='Error:'||pag_cta.G_MSJ_ERROR;
                         UPDATE simgia_debcreit SET respuesta=v_error,estado=9 WHERE nro_cuenta=c_datos_deuda.nro_cuenta and itref = c_datos_deuda.itref and cod_persona = c_datos_deuda.cod_persona and itmonto = c_datos_deuda.mto_deuda;
                         LP_INS_MOV_ERROR;
                      END IF;
                      IF v_band_error = 0 THEN
                         v_error := 'Respuesta: '|| to_char(pag_cta.G_OK_PROCESAR) || ' msj: '|| to_char(pag_cta.G_MSJ_ERROR);
                         UPDATE simgia_debcreit SET respuesta=v_error,estado=1 WHERE nro_cuenta=c_datos_deuda.nro_cuenta and itref = c_datos_deuda.itref and cod_persona = c_datos_deuda.cod_persona and itmonto = c_datos_deuda.mto_deuda;
                      END IF;
                  END IF;
            EXIT WHEN c_deuda_pendientes%NOTFOUND;
       END LOOP;
       CLOSE c_deuda_pendientes;
  EXCEPTION
  WHEN OTHERS THEN
       v_error:='Error:'||pag_cta.g_ctas.nro_cuenta||SQLERRM;
       UPDATE simgia_debcreit SET respuesta=v_error,estado=9 WHERE nro_cuenta=c_datos_deuda.nro_cuenta and itref = c_datos_deuda.itref and cod_persona = c_datos_deuda.cod_persona and itmonto = c_datos_deuda.mto_deuda;
       LP_INS_MOV_ERROR;
       RAISE_APPLICATION_ERROR(-20000,'Error:'||pag_cta.g_ctas.nro_cuenta||sqlerrm);
  END;
end PRG_DEB_AUT_AS400;
/

