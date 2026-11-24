CREATE OR REPLACE PROCEDURE IT.prg_pro_dat_tarjetas IS
      CURSOR tarjetas IS
         SELECT b.cod_persona,
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                a.cod_moneda,
                nvl(a.sal_facturar, 0) + nvl(a.sal_facturado, 0) + nvl(a.sal_financiado, 0) +
                nvl(a.sal_cuo_pendientes, 0) saldo,
                nvl(a.lin_credito, 0) + nvl(a.lin_cuotas, 0) linea_de_credito,
                nvl(a.dia_mora, 0) dia_mora,
                a.estado,
                a.cod_rub_economico  
           FROM ge_cta_clientes b, ta_cta_tarjetas a
          WHERE b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P' --principales de cuenta
            AND ((a.estado <> 'C'
            AND EXISTS (SELECT t.nro_cuenta
                   FROM ta_tarjetas t
                  WHERE t.nro_cuenta = a.nro_cuenta
                    AND t.vigente = 'S')) or (a.estado = 'C' and a.fec_cancelacion = pag_cal.fu_obt_fec_actual(6)));
      --rv_oper    ge_cla_operaciones_tmp%ROWTYPE;
      ww_ttdeuda NUMBER(18);
      ww_ttdeuco NUMBER(18);
      v_gar_operacion  NUMBER(18,2);
      v_fec_proceso DATE;-- := pag_cal.fu_obt_fec_actual(6);
      v_error varchar2(4000):= null;
      v_prevision ta_previsiones.monto%TYPE;
      
   BEGIN
       v_fec_proceso := pag_cal.fu_obt_fec_actual(6);
       -- truncar la tabla temporal
       execute immediate('TRUNCATE TABLE ge_cla_operaciones_tmp');
       
       FOR ta IN tarjetas LOOP
         BEGIN
           --Recupero la prevision de la tarjeta
           SELECT pr.monto
             INTO v_prevision
             FROM ta_previsiones pr
            WHERE pr.fecha =
                  (SELECT MAX(pv.fecha) FROM ta_previsiones pv WHERE pr.nro_cuenta = pv.nro_cuenta)
              AND pr.nro_cuenta = ta.nro_cuenta;
         EXCEPTION
           WHEN no_data_found THEN
              v_prevision := 0;
         END;
         ---1. calculo la deuda en la moneda local ----------------------
         ww_ttdeuda := it.pap_cat.fu_con_a_guaranies(ta.cod_moneda, ta.saldo);
         IF ta.estado != 'B' THEN
           IF nvl(ta.saldo, 0) >= nvl(ta.linea_de_credito, 0) THEN
              ww_ttdeuco := 0;
           ELSE
              IF nvl(ww_ttdeuda, 0) < 0 THEN
               -- si tiene un credito (saldo neg.) se considera solo la linea
                 ww_ttdeuco := nvl(ta.linea_de_credito, 0);
                 ww_ttdeuda := 0;
              ELSE
                 ww_ttdeuco := (nvl(ta.linea_de_credito, 0) - nvl(ta.saldo, 0));
              END IF;
            END IF;
         ELSE
           ww_ttdeuco := 0;
           IF nvl(ww_ttdeuda, 0) < 0 THEN
             ww_ttdeuda := 0;
           end if;
         END IF;
         -- garantias x operacion
         v_gar_operacion := it.pap_cat.fu_obt_tot_gar_x_ope(ta.nro_cuenta, null);
         ww_ttdeuco := it.pap_cat.fu_con_a_guaranies(ta.cod_moneda, ww_ttdeuco);

         ---2. inserto el registro de la operacion ----------------------
         BEGIN
           insert into ge_cla_operaciones_tmp
            (cod_persona,
             nro_cuenta,
             fecha,
             cod_modulo,
             cod_modalidad,
             cod_estado,
             tot_deu_real,
             tot_deu_contingente,
             dia_atraso,
             cod_moneda,
             cod_oficina,
             tipo,
             cod_sec_credito,
             mto_original,
             tip_destino,
             cod_rub_economico,
             tot_gar_computables,
             tot_prevision)
           values
             (ta.cod_persona,
              ta.nro_cuenta,
              v_fec_proceso,
              ta.cod_modulo,
              ta.cod_modalidad,
              ta.estado,
              ww_ttdeuda,
              ww_ttdeuco,
              ta.dia_mora,
              ta.cod_moneda,
              ta.cod_oficina,
              'A',
              701,
              nvl(ww_ttdeuda, 0) + nvl(ww_ttdeuco, 0),
              4, --- Consumo
              ta.cod_rub_economico,
              v_gar_operacion,
              it.pap_cat.fu_con_a_guaranies(ta.cod_moneda,v_prevision));
         EXCEPTION
           when others then
             v_error := SQLERRM;
             insert into ge_log_errores
                    (cod_programa, 
                     cod_persona, 
                     nro_cuenta, 
                     fecha,
                     det_error, 
                     usu_insercion, 
                     fec_insercion, 
                     usu_modificacion, 
                     fec_modificacion)
             values
                     ('PRG_PRO_DAT_TARJETAS',
                      ta.cod_persona,
                      ta.nro_cuenta,
                      v_fec_proceso,
                      v_error,
                      user,
                      sysdate,
                      user,
                      sysdate);
         END;
      END LOOP;
      
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error al procesar el temporal de tarjetas ' || SQLERRM);

   END;
/
