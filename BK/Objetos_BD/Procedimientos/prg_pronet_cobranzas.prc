CREATE OR REPLACE PROCEDURE IT.PRG_PRONET_COBRANZAS is
    /*
      Toma los datos de la tabla GE_MOV_PRO_COBRANZAS cuyos datos son insertados desde el procedimiento PR_INS_COB_PRONET e
      Inserta los datos en GE_MOVIMIENTOS durante el cierre Cod_proceso 11 Orden 196.-
    */
    v_fec_actual     date := pag_cal.FU_OBT_FEC_ACTUAL(3);
    v_cod_oficina    number  (4):= 31;
    v_nro_secuencia  number  (4);
    v_hora           varchar2(8);
    r_gmovi          ge_movimientos%rowtype;


    Function lf_obt_cob_rubro(p_cod_modulo      in number  ,
                              p_cod_modalidad   in number  ,
                              p_cod_transaccion in number  ,
                              p_cod_moneda      in varchar2,
                              p_tip_movimiento  in varchar2) return varchar2 Is

         v_cod_rubro varchar2(20);

        Begin
          select cod_rubro
            into v_cod_rubro
            from ge_tip_asientos b, ge_transacciones a
           where a.cod_modulo        = p_cod_modulo
             and a.cod_modalidad     = p_cod_modalidad
             and a.cod_transaccion   = p_cod_transaccion
             and b.cod_tip_asiento   = a.cod_tip_asiento
             and b.cod_moneda        = p_cod_moneda
             and (b.cod_sec_contable = 'X' or b.cod_sec_contable is null)
             and b.tip_movimiento    = p_tip_movimiento;
          return v_cod_rubro;
        End;

    -- Recupera los datos de la cuenta ficticia
    Procedure lp_obt_cta_ficticia(p_nro_tarjeta     in varchar2    ,
                                  p_cod_modulo      in out number  ,
                                  p_cod_modalidad   in out number  ,
                                  p_cod_oficina     in out number  ,
                                  p_nro_cta_tarjeta in out varchar2) is
        Begin
             If p_nro_tarjeta is not null Then
                -- si es una tarjeta, busco la modalidad de la tarjeta
                select c.cod_modulo , c.cod_modalidad, c.cod_oficina, c.nro_cuenta
                  into p_cod_modulo , p_cod_modalidad, p_cod_oficina, p_nro_cta_tarjeta
                  from ta_cta_tarjetas c, ta_tarjetas t
                 where t.nro_tarjeta = p_nro_tarjeta
                   and t.nro_cuenta  = c.nro_cuenta
                   and rownum = 1;
             End if;

        Exception
            WHEN NO_DATA_FOUND THEN
                 p_cod_modulo := NULL;
                 p_cod_modalidad :=null;
            WHEN OTHERS THEN
                 raise_application_error(-20000,'Error al verificar cta. ficticia: ' || SQLERRM);
        end;
    -- obtiene la fecha de proceso
    function lf_obt_fec_proceso(p_fecha in date)
        Return Date Is
        v_retorno date := p_fecha;
        Begin
            For i in 1..2 Loop
                v_retorno := pag_cal.fu_obt_fec_habil(v_retorno-1,-1, 1);
            End Loop;
            return v_retorno;
        End;

    -- Genera el movimiento contable por la transaccion generada a traves de Pronet
    PROCEDURE lp_gen_mov_contable IS
          CURSOR cuentas IS
                  SELECT nro_cta_debito    ,
                         nro_cta_credito   ,
                         cod_moneda        ,
                         monto             ,
                         fecha             ,
                         hora              ,
                         a.nro_boleta   nro_documento4,
                         a.nro_lote     nro_documento ,
                         a.observacion  concepto      ,
                         nro_tarjeta       ,
                         rowid fila
                    FROM GE_MOV_PRO_COBRANZAS a
                   WHERE liberado  = 'N'
                     AND reversado = 'N'
                     and a.estado  = 'N'
                     and not exists(Select 1
                                    From ge_movimientos ax
                                    where a.nro_lote   = ax.nro_documento
                                      and a.nro_boleta = ax.nro_documento4);

          v_cod_mon_credito VARCHAR2(03 ) := pag_gen.FU_OBT_MON_LOCAL;
          v_cod_tra_credito NUMBER  (04 ) := 5109; -- Credito Tarjetas Pronet
          v_cod_mod_credito NUMBER  (03 ) ;
          v_cod_mad_credito NUMBER  (03 ) ;
          v_cod_ofi_credito NUMBER  (5  ) ;
          v_nro_cta_tarjeta VARCHAR2(20 ) ;
          v_lugar           VARCHAR2(300) ;
      BEGIN
          v_nro_secuencia := 0;
          FOR CC IN cuentas LOOP
              v_lugar := 'Procesando.... Debito a: '||cc.nro_cta_debito||'  Credito a: '||cc.nro_cta_credito;
              lp_obt_cta_ficticia( cc.nro_tarjeta    ,
                                   v_cod_mod_credito ,
                                   v_cod_mad_credito ,
                                   v_cod_ofi_credito ,
                                   v_nro_cta_tarjeta );
              IF v_cod_mod_credito = 5  THEN
                  If v_nro_secuencia > 990 Then
                  /* DYDMR-5798 - 02/01/2017 : Se remplaza la forma de obtener la hora siguiente 
                     utilizando la funcion fug_obt_hor_disponible
                   */
                     v_hora          :=  fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N'); --pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
                     v_nro_secuencia := 0;
                  End If;
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.cod_usuario     := user;
                  r_gmovi.hora            := v_hora;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.cod_modulo      := v_cod_mod_credito;
                  r_gmovi.cod_modalidad   := v_cod_mad_credito;
                  r_gmovi.cod_oficina     := nvl(v_cod_ofi_credito,v_cod_oficina);
                  r_gmovi.nro_cuenta      := v_nro_cta_tarjeta;
                  r_gmovi.cod_moneda      := v_cod_mon_credito;
                  r_gmovi.fecha           := v_fec_actual;
                  r_gmovi.fec_valor       := cc.fecha;
                  r_gmovi.concepto        := cc.concepto;
                  r_gmovi.cod_tra_padre   := v_cod_tra_credito;
                  r_gmovi.cod_transaccion := v_cod_tra_credito;
                  r_gmovi.nro_documento   := cc.nro_documento;
                  r_gmovi.nro_documento3  := null;
                  r_gmovi.nro_documento4  := cc.nro_documento4;
                  r_gmovi.monto           := cc.monto;
                  r_gmovi.estado          := 'N';
                  r_gmovi.cod_ofi_origen  := v_cod_oficina;
                  r_gmovi.reversado       := 'N';
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.protegido       := 'N';
                  r_gmovi.cod_mod_padre   := v_cod_mod_credito;
                  r_gmovi.cod_mad_padre   := v_cod_mad_credito;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
              END IF;
              UPDATE GE_MOV_PRO_COBRANZAS
                 SET ESTADO = 'S'
               WHERE rowid = cc.fila;
          END LOOP;
      EXCEPTION
          WHEN OTHERS THEN
               Raise_Application_Error(-20000,'Error al procesar cobr. diarias: '||v_lugar || SQLERRM);
      END;


      -- PROCESO LA OPERACION DE ACUERDO A LA FECHA DE PAGO PROVENIENTE DEL ARCHIVO DE PRONET
      PROCEDURE lp_deb_pendientes IS
          v_cod_tra_padre     number  (04 ):= 5110;
          v_cod_mon_debito    varchar2(04 );
          v_cod_tra_debito    number  (04 );
          v_cod_mon_credito   varchar2(04 );
          v_cod_mod_credito   number  (04 );
          v_cod_mad_credito   number  (04 );
          v_cod_tra_credito   number  (04 );
          v_msj_error         varchar2(200);
          v_es_ficticia       VARCHAR2(1  );
          v_lugar             varchar2(200);
          v_cod_modulo        number  (4  );
          v_cod_modalidad     number  (4  );
          v_nvo_estado        varchar2(1  );
          v_sal_disponible    number  (18,2);
          v_procesa           varchar2(1  );
          v_cod_ofi_credito   number  (5  );
          v_nro_cta_tarjeta   varchar2(20 );
          v_mto_tot_debito    number  (18,2) := 0;--Para sumar el monto total y se registre en un solo registro. SF
          v_nro_cta_debito    varchar2(20 );

          CURSOR cuentas IS
                SELECT nro_cta_debito  ,
                       nro_cta_credito ,
                       cod_moneda      ,
                       monto           ,
                       fecha           ,
                       hora            ,
                       a.nro_boleta   nro_documento4,
                       a.nro_lote     nro_documento ,
                       a.observacion  concepto      ,
                       nro_tarjeta     ,
                       a.fecha_pago    ,
                       rowid fila
                  FROM GE_MOV_PRO_COBRANZAS a
                 WHERE liberado     = 'N'
                   AND reversado    = 'N'
                   and a.estado     = 'S'
                   AND A.FECHA_PAGO <= pag_cal.FU_OBT_FEC_ACTUAL(3)
                   and not exists(Select 1
                                    From ge_movimientos ax
                                    where a.nro_lote   = ax.nro_documento
                                      and a.nro_boleta = ax.nro_documento4
                                      and a.fecha      = pag_cal.FU_OBT_FEC_ACTUAL(3));

        BEGIN
            v_nro_secuencia := 0;
            FOR CC IN cuentas LOOP
                v_msj_error   := NULL;
                v_es_ficticia := 'N';

                if v_nro_secuencia > 990 then
                   /* DYDMR-5798 - 02/01/2017 : Se remplaza la forma de obtener la hora siguiente 
                      utilizando la funcion fug_obt_hor_disponible
                   */
                   v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N'); --pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
                   v_nro_secuencia := 0;
                end if;

                v_lugar            := 'Procesando.... Debito a: '||cc.nro_cta_debito||'  Credito a: '||cc.nro_cta_credito;
                v_cod_tra_credito  := 602;
                v_cod_tra_debito   := 503;
                pag_cta.PR_VER_OPERACION(cc.nro_cta_debito ,
                                         v_cod_tra_padre   ,
                                         4                 ,
                                         41                ,
                                         'D'               ,
                                         cc.cod_moneda     ,
                                         cc.monto          ,
                                         v_cod_oficina     ,
                                         v_cod_modulo      ,
                                         v_cod_modalidad   ,
                                         v_nvo_estado      ,
                                         v_sal_disponible  ,
                                         v_procesa         ,
                                         v_cod_tra_debito  );
                v_cod_mon_debito   := pag_cta.g_CTAS.COD_MONEDA;

                if v_procesa = 'N' then
                   v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
                end if;

                IF v_msj_error IS NULL THEN
                   v_lugar := 'Obtiendo cuenta ficticia '||cc.nro_cta_credito;
                   lp_obt_cta_ficticia (cc.nro_tarjeta    ,
                                        v_cod_mod_credito ,
                                        v_cod_mad_credito ,
                                        v_cod_ofi_credito ,
                                        v_nro_cta_tarjeta );
                   IF v_cod_mod_credito = 5  THEN
                      v_es_ficticia     := 'S';
                      v_cod_tra_credito := 5109; -- credito tarjetas bancard
                      v_cod_mon_credito := pag_gen.fu_obt_mon_local;
                      pag_cta.pr_set_nro_documento3(null);
                      --SF. se solicitó que se genere en un solo registro el monto para la cuenta debito
                      /*pag_cta.PR_SET_COD_RUBRO(111201090400699,'D');
                      pag_cta.pr_act_operacion(cc.nro_cta_debito,
                                               v_hora           ,
                                               'D'              ,
                                               cc.cod_moneda    ,
                                               cc.monto         ,
                                               v_cod_tra_padre  ,
                                               v_cod_tra_debito ,
                                               cc.nro_documento ,
                                               null             ,
                                               v_cod_oficina    ,
                                               4                ,
                                               41               ,
                                               null             ,
                                               null             ,
                                               'Pronet Cobranza',
                                               'N'              ,
                                               v_nro_secuencia  ,
                                               v_fec_actual     );
                      If pag_cta.g_cod_error <> 0 then
                         v_msj_error := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);*/
                      if cc.monto <> 0 then
                         v_nro_secuencia         := v_nro_secuencia + 1;
                         r_gmovi.cod_usuario     := user;
                         r_gmovi.hora            := v_hora;
                         r_gmovi.nro_secuencia   := v_nro_secuencia;
                         r_gmovi.cod_modulo      := v_cod_mod_credito;
                         r_gmovi.cod_modalidad   := v_cod_mad_credito;
                         r_gmovi.cod_oficina     := nvl(v_cod_ofi_credito,v_cod_oficina);
                         r_gmovi.nro_cuenta      := v_nro_cta_tarjeta;
                         r_gmovi.cod_moneda      := v_cod_mon_credito;
                         r_gmovi.fecha           := v_fec_actual;
                         r_gmovi.fec_valor       := cc.fecha;
                         r_gmovi.concepto        := cc.concepto;
                         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                         r_gmovi.cod_transaccion := null;
                         r_gmovi.nro_documento   := cc.nro_documento;
                         r_gmovi.nro_documento3  := null;
                         r_gmovi.nro_documento4  := cc.nro_documento4;
                         r_gmovi.monto           := cc.monto;
                         r_gmovi.estado          := 'N';
                         r_gmovi.cod_ofi_origen  := v_cod_oficina;
                         r_gmovi.reversado       := 'N';
                         r_gmovi.emi_aviso       := 'N';
                         r_gmovi.protegido       := 'N';
                         r_gmovi.cod_mod_padre   := 4;
                         r_gmovi.cod_mad_padre   := 41;
                         r_gmovi.tip_mov_rubro   := 'C';
                         r_gmovi.cod_rubro       := lf_obt_cob_rubro(v_cod_mod_credito, v_cod_mad_credito, v_cod_tra_credito,v_cod_mon_credito,'D');
                         pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

                         v_mto_tot_debito := v_mto_tot_debito + cc.monto;

                         UPDATE GE_MOV_PRO_COBRANZAS
                            SET liberado = 'S', ESTADO = 'P'
                          WHERE rowid = cc.fila;

                      End If;
                  ELSE
                      -- no es una cuenta ficticia, se debe realizar una transferencia
                      v_es_ficticia := 'N';
                      -- Veo el estado, la moneda y el saldo de la cuenta credito -----
                      pag_cta.pr_ver_operacion(cc.nro_cta_credito,
                                               v_cod_tra_padre   ,
                                               4                 ,
                                               41                ,
                                               'C'               ,
                                               cc.cod_moneda     ,
                                               cc.monto          ,
                                               v_cod_oficina     ,
                                               v_cod_modulo      ,
                                               v_cod_modalidad   ,
                                               v_nvo_estado      ,
                                               v_sal_disponible  ,
                                               v_procesa         ,
                                               v_cod_tra_credito );

                      v_cod_mon_credito := pag_cta.g_ctas.cod_moneda;
                      if v_procesa = 'N' then
                         v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
                      elsif v_cod_mon_credito <> v_cod_mon_debito THEN /*monedas difer,no permitir*/
                         v_cod_tra_debito := NULL;
                         v_msj_error      := 'Monedas diferentes';
                      end if;
                  END IF;
                END IF;
                IF v_msj_error IS NULL AND v_es_ficticia = 'N' and nvl(cc.monto,0) <> 0 THEN
                   v_nro_secuencia     := v_nro_secuencia + 1;
                   pag_cta.pr_set_nro_documento3(null);
                   pag_cta.pr_act_operacion(cc.nro_cta_debito ,
                                            v_hora            ,
                                            'D'               ,
                                            cc.cod_moneda     ,
                                            cc.monto          ,
                                            v_cod_tra_padre   ,
                                            v_cod_tra_debito  ,
                                            cc.nro_documento  ,
                                            null              ,
                                            v_cod_oficina     ,
                                            4                 ,
                                            41                ,
                                            null              ,
                                            null              ,
                                            'Pronet Cobranza' ,
                                            'N'               ,
                                            v_nro_secuencia   ,
                                            v_fec_actual      );
                  if pag_cta.g_cod_error <> 0 then
                     v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
                  else
                     v_nro_secuencia := v_nro_secuencia + 1;
                     pag_cta.pr_act_operacion(cc.nro_cta_credito ,
                                              v_hora             ,
                                              'C'                ,
                                              cc.cod_moneda      ,
                                              cc.monto           ,
                                              v_cod_tra_padre    ,
                                              v_cod_tra_credito  ,
                                              cc.nro_documento   ,
                                              null               ,
                                              v_cod_oficina      ,
                                              4                  ,
                                              41                 ,
                                              null               ,
                                              null               ,
                                              'Pronet Cobranza'  ,
                                              'N'                ,
                                              v_nro_secuencia    ,
                                              v_fec_actual       );
                      pag_cta.pr_set_nro_documento3(null);
                      if pag_cta.g_cod_error <> 0 then
                         v_msj_error := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
                      end if;
                   end if;
                   if v_msj_error is null then
                      UPDATE GE_MOV_PRO_COBRANZAS
                         SET liberado = 'S', ESTADO = 'P'
                       WHERE rowid    = cc.fila;
                   else
                      UPDATE GE_MOV_PRO_COBRANZAS
                         SET observacion = v_msj_error
                       WHERE rowid       = cc.fila;
                   end if;
                end if;
                if  v_msj_error is not null then
                  UPDATE GE_MOV_PRO_COBRANZAS
                     SET observacion = v_msj_error
                   WHERE rowid       = cc.fila;
                END IF;
            v_nro_cta_debito := cc.nro_cta_debito;
            END LOOP;
            pag_cta.PR_VER_OPERACION(v_nro_cta_debito  ,
                                     v_cod_tra_padre   ,
                                     4                 ,
                                     41                ,
                                     'D'               ,
                                     v_cod_mon_debito  ,
                                     v_mto_tot_debito  ,
                                     v_cod_oficina     ,
                                     v_cod_modulo      ,
                                     v_cod_modalidad   ,
                                     v_nvo_estado      ,
                                     v_sal_disponible  ,
                                     v_procesa         ,
                                     v_cod_tra_debito  );

            if v_procesa = 'N' then
               v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
            end if;

            IF v_msj_error IS NULL THEN
              --pag_cta.PR_SET_COD_RUBRO(111201090400699,'D'); Se comenta para que tome de cc_cta_bancarias en TB_GE_MOVIMIENTOS. CB. 10/09/2013. SPI 2439
              pag_cta.pr_act_operacion(v_nro_cta_debito ,--nro_cta_debito. Banco del Pais
                                       v_hora           ,
                                       'D'              ,
                                       v_cod_mon_debito ,--cod_moneda
                                       v_mto_tot_debito ,
                                       v_cod_tra_padre  ,
                                       v_cod_tra_debito ,
                                       1                ,--nro_documento
                                       null             ,
                                       v_cod_oficina    ,
                                       4                ,
                                       41               ,
                                       null             ,
                                       null             ,
                                       'Pronet Cobranza',
                                       'N'              ,
                                       v_nro_secuencia  ,
                                       v_fec_actual     );
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                 raise_application_error(-20000,'Error al procesar cobranzas: ' || sqlerrm);
        END;

BEGIN --> Proceso Principal
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
    -- genera el debito contable en el dia de la operacion
    v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
    lp_gen_mov_contable;


    -- genera el credito y debito dependiendo de la fecha de Pago que Dice Pronet
    v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
    lp_deb_pendientes;

END;
/

