CREATE OR REPLACE PROCEDURE IT.prc_dev_che_camara(P_FECHA       IN GE_MOVIMIENTOS.FECHA%TYPE,
                                               P_NRO_CUENTA  IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE,
                                               P_NRO_CHEQUE  IN CC_CHEQUERAS.NRO_CHE_INICIAL%TYPE,
                                               P_COD_OFICINA IN GE_MOVIMIENTOS.COD_OFICINA%TYPE,
                                               P_CAUSA       IN GE_CAUSALES.COD_CAUSA%TYPE DEFAULT NULL) IS
  -- Este procedimiento realiza la devolución de los cheques C/N/B. CROAPARS-1 06/2015  V.V.
  v_che_cert          varchar2(1) := 'N';
  v_cta_cert          cc_che_certificados.nro_cta_certificado%type;
  v_cod_ofi_cert      ge_cuentas.cod_oficina%type;
  v_nro_che_inicial   cc_chequeras.nro_che_inicial%type;
  v_tas_personalizada varchar2(1) := 'N';
  v_aut_pendiente     varchar2(1) := 'N';
  v_tra_prohibida     varchar2(1) := 'N';
  v_nro_boleta        cj_movimientos.nro_documento%type;
  v_cta_deposito      cc_cta_corrientes.nro_cuenta%type;
  v_desc_cta          ge_cuentas.denominacion%type;
  v_mon_deposito      cc_cta_corrientes.cod_moneda%type;
  v_mto_deposito      cj_movimientos.monto%type;
  v_cod_modulo        cc_cta_corrientes.cod_modulo%type := 4;
  v_cod_modalidad     cc_cta_corrientes.cod_modalidad%type;
  v_cod_tra_padre     cj_movimientos.cod_tra_padre%type;
  v_cod_bco_receptor  ge_bancos.cod_banco%type;
  v_cod_ofi_camara    ba_oficinas.cod_oficina%type;
  v_nro_cuenta        cc_cta_corrientes.nro_cuenta%type;
  v_nro_cheque        cc_chequeras.nro_che_inicial%type;
  v_val_cheque        cc_cta_corrientes.sal_total%type;
  v_nro_secuencia     ge_movimientos.nro_secuencia%type := 1;
  v_hora              varchar2(08) := to_char(sysdate, 'HH24:MI:SS');
  v_fec_actual        ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(4);
  v_tra_rec_nex_dia   ge_transacciones.cod_transaccion%type;
  v_compensacion      varchar2(1);
  v_ind               varchar2(1);
  v_cod_moneda        ge_movimientos.cod_moneda%type;
  v_che_gerencia      varchar2(1) := 'N';
  v_cod_mod_pre       ba_modulos.cod_modulo%type;            

  CURSOR C_DATOS IS
    SELECT CTE.NRO_CUENTA,
           CTE.DENOMINACION,
           X.NRO_CHEQUE,
           X.MONTO VALOR,
           CTE.SAL_TOTAL,
           NVL(CTE.SAL_RETENIDO, 0) RETENIDO,
           (NVL(CTE.SAL_TOTAL, 0) - NVL(CTE.SAL_RETENIDO, 0) -
           NVL(CTE.SAL_BLOQUEADO, 0)) SOBREGIRO,
           SOB.CAN_DIAS,
           X.COD_OFI_CAMARA,
           CT.COD_OFICINA,
           CT.COD_PERSONA,
           CTE.COD_MONEDA,
           X.IND,
           PER.MONTO LIN_SOB_APROBADA
      FROM GE_CTA_CLIENTES CT,
           GE_CLIENTES CL,
           GE_TIP_DEUDORES DE,
           CC_LIN_SOBREGIROS PER,
           GE_SEC_CONTABLES SE,
           BA_MONEDAS B,
           BA_OFICINAS O,
           CC_CTA_CORRIENTES CTE,
           CC_SOBREGIROS_RES SOB,
           BA_USUARIOS USU,
           ( -- RECIBIDOS DE CAMARA --
            SELECT A.NRO_CUENTA,
                    A.NRO_CHEQUE,
                    B.DENOMINACION,
                    B.COD_MONEDA,
                    A.MONTO,
                    A.COD_OFI_CAMARA,
                    1 IND
              FROM CC_CHE_RECIBIDOS A, GE_CUENTAS B
             WHERE A.NRO_CUENTA = B.NRO_CUENTA
               AND A.FEC_PROCESO = P_FECHA
               AND A.EST_CHEQUE = 'P'
               AND EXISTS (SELECT 1
                      FROM BA_OFICINAS Z
                     WHERE Z.COD_OFI_CAMARA = A.COD_OFI_CAMARA
                       AND Z.COD_OFI_CAMARA IS NOT NULL)
            UNION
            SELECT A.NRO_CUENTA,
                   A.NRO_CHEQUE,
                   B.DENOMINACION,
                   B.COD_MONEDA,
                   A.MONTO,
                   A.COD_OFI_CAMARA,
                   3 IND
              FROM CC_CHE_RECIBIDOS A, GE_CUENTAS B
             WHERE A.NRO_CUENTA = B.NRO_CUENTA
               AND A.FEC_PROCESO = P_FECHA
               AND A.EST_CHEQUE = 'P'
               AND NOT EXISTS
             (SELECT 1
                      FROM BA_OFICINAS Z
                     WHERE Z.COD_OFI_CAMARA = A.COD_OFI_CAMARA
                       AND Z.COD_OFI_CAMARA IS NOT NULL)
            union
            -- DEPOSITADOS EN CUENTA --
            SELECT DET.NRO_CUENTA,
                   DET.NRO_DOCUMENTO NRO_CHEQUE,
                   CTA.DENOMINACION,
                   DET.COD_MONEDA,
                   DET.MONTO,
                   NULL,
                   2                 IND
              FROM CJ_MOVIMIENTOS DET, CJ_MOVIMIENTOS DEP, GE_CUENTAS CTA
             WHERE DET.COD_TRA_PADRE IN (320, 355)
               AND DET.NRO_DOC_REFERENCIA = DEP.NRO_DOCUMENTO
               AND DEP.TIP_MONTO = 'C'
               AND DEP.TIPO = 'D'
               AND DET.ESTADO = 'N'
               AND DEP.ESTADO = 'N'
               AND DET.NRO_CUENTA = CTA.NRO_CUENTA
               AND EXISTS (SELECT 1
                      FROM CC_CHE_PAGADOS P
                     WHERE P.NRO_CUENTA = DET.NRO_CUENTA
                       AND P.NRO_CHEQUE = DET.NRO_DOCUMENTO
                       AND P.FECHA = DET.FECHA
                       AND P.COD_CAU_DEVOLUCION IS NULL)
             union
              -- DEPOSITADOS EN CUENTA CHEQUES HIBRIDOS--
            SELECT DET.NRO_CUENTA,
                   DET.NRO_DOCUMENTO NRO_CHEQUE,
                   CTA.DENOMINACION,
                   DET.COD_MONEDA,
                   DET.MONTO,
                   NULL,
                   4                 IND
              FROM GE_MOVIMIENTOS DET, GE_CUENTAS CTA
             WHERE DET.COD_TRA_PADRE = 345
               AND DET.REVERSADO = 'N'
               AND DET.ESTADO = 'N'
               AND DET.NRO_CUENTA = CTA.NRO_CUENTA
               AND EXISTS (SELECT 1
                            FROM CC_CHE_PAGADOS P
                           WHERE P.NRO_CUENTA = DET.NRO_CUENTA
                             AND P.NRO_CHEQUE = DET.NRO_DOCUMENTO
                             AND P.FECHA = DET.FECHA
                             AND P.COD_CAU_DEVOLUCION IS NULL)) x
     WHERE X.NRO_CUENTA = CTE.NRO_CUENTA
       AND CTE.NRO_CUENTA = CT.NRO_CUENTA
       AND CTE.NRO_CUENTA = SOB.NRO_CUENTA(+)
       AND CT.RELACION = 'P'
       AND CT.COD_PERSONA = CL.COD_PERSONA
       AND CL.COD_SEC_CONTABLE = SE.COD_SEC_CONTABLE
       AND CL.COD_TIP_DEUDOR = DE.COD_TIP_DEUDOR
       AND DE.COD_SEC_CONTABLE = SE.COD_SEC_CONTABLE
       AND CTE.COD_MONEDA = B.COD_MONEDA
       AND USU.COD_OFICINA = O.COD_OFICINA
       AND CL.COD_USU_OFICIAL = USU.COD_USUARIO
       AND CTE.NRO_CUENTA = PER.NRO_CUENTA(+)
       AND PER.ESTADO(+) = 'A'
       AND NVL(CTE.SAL_TOTAL, 0) + NVL(PER.MONTO, 0) -
           NVL(CTE.SAL_RETENIDO, 0) - NVL(CTE.SAL_BLOQUEADO, 0) < 0
       --AND USU.COD_OFICINA = P_COD_OFICINA
       AND X.NRO_CUENTA = P_NRO_CUENTA
       AND X.NRO_CHEQUE = P_NRO_CHEQUE
     ORDER BY 2;

  PROCEDURE PP_VER_CHE_CERTIFICADO IS
    v_existe varchar2(1);
  begin
    begin
      v_che_cert := 'S';
    
      select 'S', nro_cta_certificado, ge.cod_oficina
        into v_existe, v_cta_cert, v_cod_ofi_cert
        from cc_che_certificados cc, ge_cuentas ge
       where cc.nro_cuenta = V_NRO_CUENTA
         and cc.nro_cheque = V_NRO_CHEQUE
         and cc.nro_cta_certificado = ge.nro_cuenta;
    
    exception
      when no_data_found then
         v_che_cert := 'N';
      when too_many_rows then
         raise_application_error(-20000,'Existen varios registros en cc_che_certificados');
    end;
    if v_che_cert = 'S' then
       v_tas_personalizada := 'N';
       v_aut_pendiente     := 'N';
       v_tra_prohibida     := 'N';
    end if;
  end;

  PROCEDURE PP_VAL_EST_CHEQUE IS
    v_estado varchar2(1);
    v_error  varchar2(4000);
    v_cuenta varchar2(20);
  
  BEGIN
    V_ESTADO := PAC_CHE.FU_CON_CAM_EST_CHE(V_NRO_CUENTA,
                                           V_NRO_CHEQUE,
                                           NULL,
                                           NULL,
                                           V_NRO_CHE_INICIAL,
                                           V_ERROR,
                                           V_CUENTA);
    If v_estado = 'O' then
      raise_application_error(-20000,'Cheque se encuentra con estado orden de no pagar');
    Elsif v_estado not in ('C', 'G', 'P') then
      raise_application_error(-20000,'Cheque no se puede devolver. estado invalido');
    End if;
  
    If instr(v_error, 'Inexistente') <> 0 then
      raise_application_error(-20000, v_error);
    End if;
  
    pp_ver_che_certificado;
  
  EXCEPTION
    when others then
      raise_application_error(-20000, 'Error ' || sqlerrm);
  END;

  PROCEDURE PP_VERIFICAR_CHE_PROCESADOS IS
    v_importe number(21, 2);
  begin
    v_nro_boleta    := null;
    v_cta_deposito  := null;
    v_desc_cta      := null;
    v_mon_deposito  := null;
    v_mto_deposito  := null;
    v_cod_tra_padre := null;
  
    select monto, cod_bco_receptor, nvl(com_directa, 'N')
      into v_importe, v_cod_bco_receptor, v_compensacion
      from cc_che_recibidos
     where fec_proceso = P_FECHA
       and cod_ofi_camara = v_cod_ofi_camara
       and nro_cuenta = v_nro_cuenta
       and nro_cheque = v_nro_cheque
       and est_cheque = 'P';
  
    if nvl(v_importe, 0) <> nvl(v_val_cheque, 0) then
      raise_application_error(-20000,'Importe del cheque no coincide con lo procesado');
    end if;
  
  exception
    when no_data_found then
      --Verificar si el cheque fue depositado
      begin
        select monto, cod_tra_padre, nro_documento
          into v_importe, v_cod_tra_padre, v_nro_boleta
          from ge_movimientos
         where cod_tra_padre in (355, 345)
           and estado = 'N'
           and reversado = 'N'
           and fecha = P_FECHA
           and monto is not null
           and nro_documento = v_nro_cheque
           and nro_cuenta = v_nro_cuenta;
      
        if nvl(v_importe, 0) <> nvl(v_val_cheque, 0) then
          raise_application_error(-20000,'Importe del cheque no coincide con lo procesado');
        end if;
      
        --Obtener datos del deposito
       if v_cod_tra_padre = 355 then -- solo para transacciones detalladas en caja, 345 se detalla en caja de gnbpy 
        begin
          select dep.nro_documento,
                 dep.nro_cuenta,
                 cta.denominacion,
                 dep.cod_moneda,
                 dep.monto,
                 dep.cod_tra_padre
            into v_nro_boleta,
                 v_cta_deposito,
                 v_desc_cta,
                 v_mon_deposito,
                 v_mto_deposito,
                 v_cod_tra_padre
          
            from cj_movimientos det, cj_movimientos dep, ge_cuentas cta
           where det.nro_cuenta = v_nro_cuenta
             and det.nro_documento = v_nro_cheque
             and det.cod_tra_padre = 355
             and det.cod_moneda = dep.cod_moneda
             and det.nro_doc_referencia = dep.nro_documento
             and det.estado = 'N'
             and dep.estado = 'N'
             and dep.nro_cuenta = cta.nro_cuenta
             and dep.tip_monto = 'C';
        exception
          when others then
            begin
              select dep.nro_documento,
                     dep.nro_cuenta,
                     cta.denominacion,
                     dep.cod_moneda,
                     dep.monto,
                     dep.cod_tra_padre
                into v_nro_boleta,
                     v_cta_deposito,
                     v_desc_cta,
                     v_mon_deposito,
                     v_mto_deposito,
                     v_cod_tra_padre
                from cj_movimientos det, cj_movimientos dep, ge_cuentas cta
               where det.nro_cuenta = v_nro_cuenta
                 and det.nro_documento = v_nro_cheque
                 and det.cod_tra_padre = 355
                 and det.cod_moneda = dep.cod_moneda
                 and det.nro_doc_referencia = dep.nro_documento
                 and det.estado = 'N'
                 and dep.estado = 'N'
                 and dep.cod_tra_padre = 206
                 and dep.tip_monto = 'C'
                 and dep.nro_cuenta = cta.nro_cuenta(+);
            exception
              when no_data_found then
                raise_application_error(-20000,'No se encontraron datos del depósito, Cuenta: ' || v_nro_cuenta || ', Cheque Nro.: ' ||v_nro_cheque);
            end;
        end;
      end if; -- transacc 355  
      exception
        when no_data_found then
          begin
            select monto, cod_tra_padre, nro_documento
              into v_importe, v_cod_tra_padre, v_nro_boleta
              from cc_movimientos_his
             where cod_tra_padre in (355, 345)
               and estado = 'N'
               and reversado = 'N'
               and fecha = P_FECHA
               and monto is not null
               and nro_documento = v_nro_cheque
               and nro_cuenta = v_nro_cuenta;
          
            if nvl(v_importe, 0) <> nvl(v_val_cheque, 0) then
              raise_application_error(-20000,'Importe del cheque no coincide con lo procesado');
            end if;
            
          if v_cod_tra_padre = 355 then -- solo si fue detallado en caja, 345 se detallo en caja gnbpy
            begin
              select dep.nro_documento,
                     dep.nro_cuenta,
                     cta.denominacion,
                     dep.cod_moneda,
                     dep.monto,
                     dep.cod_tra_padre
                into v_nro_boleta,
                     v_cta_deposito,
                     v_desc_cta,
                     v_mon_deposito,
                     v_mto_deposito,
                     v_cod_tra_padre
                from cj_movimientos_his det,
                     cj_movimientos_his dep,
                     ge_cuentas         cta
               where dep.fecha = P_FECHA
                 and det.fecha = dep.fecha
                 and det.nro_cuenta = v_nro_cuenta
                 and det.nro_documento = v_nro_cheque
                 and det.cod_tra_padre = 355
                 and det.cod_moneda = dep.cod_moneda
                 and det.nro_doc_referencia = dep.nro_documento
                 and det.estado = 'N'
                 and dep.estado = 'N'
                 and dep.nro_cuenta = cta.nro_cuenta
                 and dep.tip_monto = 'C';
            exception
              when others then
                begin
                  select dep.nro_documento,
                         dep.nro_cuenta,
                         cta.denominacion,
                         dep.cod_moneda,
                         dep.monto,
                         dep.cod_tra_padre
                    into v_nro_boleta,
                         v_cta_deposito,
                         v_desc_cta,
                         v_mon_deposito,
                         v_mto_deposito,
                         v_cod_tra_padre
                    from cj_movimientos_his det,
                         cj_movimientos_his dep,
                         ge_cuentas         cta
                   where dep.fecha = P_FECHA
                     and det.fecha = dep.fecha
                     and det.nro_cuenta = v_nro_cuenta
                     and det.nro_documento = v_nro_cheque
                     and det.cod_tra_padre = 355
                     and det.cod_moneda = dep.cod_moneda
                     and det.nro_doc_referencia = dep.nro_documento
                     and det.estado = 'N'
                     and dep.estado = 'N'
                     and dep.cod_tra_padre = 206
                     and dep.tip_monto = 'C'
                     and dep.nro_cuenta = cta.nro_cuenta(+);
                exception
                  when no_data_found then
                    raise_application_error(-20000,'No se encontraron datos del depósito, Cuenta: ' ||v_nro_cuenta ||', Cheque Nro.: ' ||v_nro_cheque);
                end;
            end;
           end if;-- fin transac 355    
          exception
            when no_data_found then
              raise_application_error(-20000,'El Cheque ' || v_nro_cheque ||' no fue procesado en esta fecha');
          end;
       end;
    when too_many_rows then
      raise_application_error(-20000, 'Existen registros duplicados');
    when others then
      raise_application_error(-20000, 'En PRC_RCH_CHE_CAMARA ' || sqlerrm);
  end;

  PROCEDURE PP_PRO_DEV_DEPOSITO IS
    r_gmovi ge_movimientos%rowtype;
  
  BEGIN
    v_nro_secuencia := v_nro_secuencia + 1;
    pag_cta.PR_ACT_OPERACION(v_nro_cuenta,
                             v_hora,
                             'C',
                             fug_obt_mon_cta(v_nro_cuenta),
                             v_val_cheque,
                             132,
                             602,
                             v_nro_cheque,
                             NULL,
                             fug_obt_ofi_camara(P_COD_OFICINA),
                             v_cod_modulo,
                             v_cod_modalidad,
                             null,
                             null,
                             null,
                             'N',
                             v_nro_secuencia,
                             P_FECHA,
                             null,
                             null);
    if pag_cta.fu_obt_cod_error() <> 0 then
      raise_application_error(-20000,pag_cta.fu_obt_cod_error() || ' - ' ||pag_cta.fu_obt_msj_error());
    end if;
  
    if nvl(V_COD_TRA_PADRE, 999) not in (206, 345) then -- se agrega 345 de cheques hibridos, el debito se hace a un rub transitorio
    
      if v_cta_deposito is not null then
        select c.cod_modulo
          into v_cod_mod_pre
          from ge_cuentas c
         where c.nro_cuenta = v_cta_deposito;
      
        if v_cod_mod_pre = 6 then
          raise_application_error(-20000,'El cheque corresponde a un Cobro de Cuota del Préstamo Nro. ' ||v_cta_deposito ||', se debe Reversar el Cobro.');
        end if;
      end if;
    
      --Libera antes el deposito para no tener problemas (Para Cámara Interna)...
      update ah_retenciones
         set lib_posterior = 'S'
       where nro_cuenta = v_cta_deposito
         and nro_documento = v_nro_boleta
         and liberado = 'N';
    
      PRA_LIB_RETENCION(V_CTA_DEPOSITO,
                        V_CTA_DEPOSITO,
                        'S',
                        'S',
                        V_NRO_BOLETA,
                        v_val_cheque);
    
      --Debitar a la Cta. del depósito
      pag_cta.PR_ACT_OPERACION(v_cta_deposito,
                               v_hora,
                               'D',
                               v_mon_deposito,
                               v_val_cheque,
                               132,
                               503,
                               v_nro_cheque,
                               NULL,
                               fug_obt_ofi_camara(P_COD_OFICINA),
                               v_cod_modulo,
                               v_cod_modalidad,
                               null,
                               null,
                               null,
                               'N',
                               v_nro_secuencia,
                               P_FECHA,
                               null,
                               null);
      if pag_cta.fu_obt_cod_error() <> 0 then
        raise_application_error(-20000,pag_cta.fu_obt_cod_error() || ' - ' ||pag_cta.fu_obt_msj_error());
      end if;
    else
      r_gmovi := null;
      --Buscar Movimiento de Ingresos Varios    
      if v_cod_tra_padre = 206 then
        begin
          select a.cod_moneda,
                 a.cod_oficina,
                 a.cod_ofi_origen,
                 a.cod_rubro,
                 a.cod_tra_padre,
                 a.cod_mod_padre,
                 a.cod_mad_padre,
                 a.nro_documento,
                 a.cod_modulo,
                 a.cod_modalidad
            into r_gmovi.cod_moneda,
                 r_gmovi.cod_oficina,
                 r_gmovi.cod_ofi_origen,
                 r_gmovi.cod_rubro,
                 r_gmovi.cod_tra_padre,
                 r_gmovi.cod_mod_padre,
                 r_gmovi.cod_mad_padre,
                 r_gmovi.nro_documento,
                 r_gmovi.cod_modulo,
                 r_gmovi.cod_modalidad
            from ge_movimientos a
           where a.nro_documento = v_nro_boleta
             and a.cod_mod_padre = 9
             and a.cod_mad_padre = 91
             and a.cod_tra_padre = 206 --Ingresos Varios
             and a.cod_transaccion = 606 --Ingreso Contable en Cheques CNB
             and a.nro_cuenta is null;
        exception
          when others then
            raise_application_error(-20000,'Al buscar datos Ingresos Varios');
        end;
      
        v_nro_secuencia := v_nro_secuencia + 1;
      
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.tip_mov_rubro   := 'D';
        r_gmovi.cod_transaccion := null;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.hora            := v_hora;
        r_gmovi.cod_usuario     := USER;
        r_gmovi.monto           := v_val_cheque;
        r_gmovi.concepto        := 'DEVOLUCION CHEQUE NRO. ' || v_nro_cheque ||
                                   ' - CUENTA: ' || v_nro_cuenta;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.protegido       := 'N';
     end if;
     
     if v_cod_tra_padre = 345 then
       begin
          select a.cod_moneda,
                 a.cod_oficina,
                 a.cod_ofi_origen,
                 a.cod_rubro,
                 a.cod_tra_padre,
                 a.cod_mod_padre,
                 a.cod_mad_padre,
                 a.nro_documento,
                 a.cod_modulo,
                 a.cod_modalidad,
                 a.referencia
            into r_gmovi.cod_moneda,
                 r_gmovi.cod_oficina,
                 r_gmovi.cod_ofi_origen,
                 r_gmovi.cod_rubro,
                 r_gmovi.cod_tra_padre,
                 r_gmovi.cod_mod_padre,
                 r_gmovi.cod_mad_padre,
                 r_gmovi.nro_documento,
                 r_gmovi.cod_modulo,
                 r_gmovi.cod_modalidad,
                 r_gmovi.referencia
            from ge_movimientos a
           where a.nro_documento = v_nro_cheque
             and a.cod_mod_padre = 4
             and a.cod_mad_padre = 41
             and a.cod_tra_padre = 345 --Detallado en GNBPY
             and a.cod_transaccion is null --
             and a.nro_cuenta is null;
        exception
          when others then
            raise_application_error(-20000,'Al buscar datos de Cheques Hibridos');
        end;
      
        v_nro_secuencia := v_nro_secuencia + 1;
      
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.tip_mov_rubro   := 'D';
        r_gmovi.cod_transaccion := null;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.hora            := v_hora;
        r_gmovi.cod_usuario     := USER;
        r_gmovi.monto           := v_val_cheque;
        r_gmovi.concepto        := 'DEVOLUCION CHEQUE NRO. ' || v_nro_cheque ||
                                   ' - CUENTA: ' || v_nro_cuenta;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.protegido       := 'N';
     end if;
              
      PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N');
    
    end if;
  
  exception
    when others then
      raise_application_error(-20000,'Error al procesar Devolución de Depósito.' ||sqlerrm);
  END;

  PROCEDURE pp_verifica_tipo_banco IS
    v_tip_banco char(01);
  begin
    select nvl(tipo, 'N')
      into v_tip_banco
      from ge_bancos
     where ge_bancos.cod_banco = v_cod_bco_receptor;
    if v_tip_banco = 'N' then
      v_tra_rec_nex_dia := 608;
    else
      v_tra_rec_nex_dia := 668;
    end if;
  exception
    when no_data_found then
      raise_application_error(-20000, 'No existe banco para el cheque');
    when too_many_rows then
      raise_application_error(-20000,'Existe mas de 1 codigo de banco para el cheque');
    when others then
      raise_application_error(-20000,'Buscando tipo de banco en PRC_RCH_CHE_CAMARA' ||sqlerrm);
  end;

  PROCEDURE pp_gen_movimiento(p_cod_transaccion in number,
                              p_monto           in number,
                              p_concepto        in varchar2) IS
    r_gmovi           ge_movimientos%rowtype;
    v_cod_transaccion ge_transacciones.cod_transaccion%type;
  BEGIN
    v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
    r_gmovi.cod_usuario   := USER;
    r_gmovi.hora          := v_hora;
    r_gmovi.nro_secuencia := v_nro_secuencia;
    r_gmovi.cod_oficina   := p_cod_oficina;
    If v_che_cert = 'N' then
      r_gmovi.nro_cuenta    := v_nro_cuenta;
      r_gmovi.cod_modulo    := v_cod_modulo;
      r_gmovi.cod_modalidad := v_cod_modalidad;
      r_gmovi.cod_moneda    := fug_obt_mon_cta(v_nro_cuenta);
    else
      r_gmovi.nro_cuenta    := v_cta_cert;
      r_gmovi.cod_modulo    := 4;
      r_gmovi.cod_oficina   := v_cod_ofi_cert;
      r_gmovi.cod_modalidad := 44;
      r_gmovi.cod_moneda    := fug_obt_mon_cta(v_cta_cert);
    end if;
  
    if P_FECHA = v_fec_actual then
      r_gmovi.fec_valor := P_FECHA;
    else
      r_gmovi.fec_valor := v_fec_actual;
    end if;
    select DECODE(v_ind, '3', 3322, 322) into v_cod_transaccion from dual;
    r_gmovi.fecha           := v_fec_actual;
    r_gmovi.cod_tra_padre   := v_cod_transaccion;
    r_gmovi.cod_transaccion := p_cod_transaccion;
    r_gmovi.nro_documento   := v_nro_cheque;
    r_gmovi.monto           := P_MONTO;
    r_gmovi.emi_aviso       := 'S';
    r_gmovi.cod_causa       := P_CAUSA;
    r_gmovi.cod_ofi_origen  := P_COD_OFICINA;
    r_gmovi.concepto        := P_CONCEPTO;
    r_gmovi.estado          := 'N';
    r_gmovi.reversado       := 'N';
    r_gmovi.protegido       := 'N';
    r_gmovi.cod_mod_padre   := v_cod_modulo;
    r_gmovi.cod_mad_padre   := v_cod_modalidad;
  
    PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N');
  exception
    when others then
      raise_application_error(-20000, 'Gen.Mov. ' || sqlerrm);
  end;

  PROCEDURE PP_COMPENSACION IS
    v_cod_transaccion ge_transacciones.cod_transaccion%type;
  
  BEGIN
    prc_obt_cta_bancaria(v_cod_bco_receptor,
                         v_cod_moneda,
                         P_COD_OFICINA,
                         v_nro_cuenta,
                         v_cod_modalidad);
  
    If v_nro_cuenta is not null then
      select DECODE(V_IND, '3', 3322, 322)
        into v_cod_transaccion
        from dual;
      pag_cta.PR_ACT_OPERACION(v_nro_cuenta,
                               v_hora,
                               'D',
                               fug_obt_mon_cta(v_nro_cuenta),
                               v_val_cheque,
                               v_cod_transaccion,
                               503,
                               v_nro_cheque,
                               NULL,
                               fug_obt_ofi_camara(P_COD_OFICINA),
                               v_cod_modulo,
                               v_cod_modalidad,
                               null,
                               null,
                               null,
                               'N',
                               v_nro_secuencia,
                               P_FECHA,
                               null,
                               null);
    else
      RAISE_APPLICATION_ERROR(-20000, 'Cta. Bancaria no existe');
    End if;
  exception
    when others then
      RAISE_APPLICATION_ERROR(-20000,'Error en PRC_RCH_CHE_CAMARA:PP_COMPENSACION ' ||sqlerrm);
  END;

  PROCEDURE PP_ACTUALIZAR_ESTADO_CHE(P_ESTADO VARCHAR2) IS
    v_poscheque number;
  BEGIN
    v_poscheque := v_nro_cheque - v_nro_che_inicial + 1;
    UPDATE cc_chequeras
       set est_cheques = substr(est_cheques, 1, v_poscheque - 1) || P_ESTADO ||
                         substr(est_cheques,
                                v_poscheque + 1,
                                length(est_cheques))
     where nro_cuenta = v_nro_cuenta
       and nro_che_inicial = v_nro_che_inicial;
    If sql%notfound then
      raise_application_error(-20000, 'Al actualizar el estado del cheque');
    End if;
    -- vuelvo a no regularizado todos los cheques similares devueltos anteriormente
    begin
      update cc_che_devueltos
         set regularizado = 'N', fec_modificacion = fec_modificacion
       where nro_cuenta = v_nro_cuenta
         and nro_cheque = v_nro_cheque;
    exception
      when others then
        null;
    end;
  END;

  PROCEDURE PP_VERIFICAR_CHE_GER(P_CHEQUE  IN NUMBER,
                                 P_CUENTA  IN VARCHAR2,
                                 P_IMPORTE IN NUMBER) IS
    v_impcheq number(16, 2);
  begin
    v_che_gerencia := 'N';
    select nvl(monto, 0)
      into v_impcheq
      from cc_che_ger_emitidos
     where nro_cheque = p_cheque
       and nro_cuenta = p_cuenta;
  
    if p_importe <> v_impcheq then
      raise_application_error(-20000,'Importe del cheque no coincide en CC_CHE_GER_EMITIDOS');
    end if;
    v_che_gerencia := 'S';
  exception
    when no_data_found then
      v_che_gerencia := 'N';    
    when too_many_rows then
      raise_application_error(-20000,'Existe mas de un CC_CHE_GER_EMITIDOS para el cheque');
  end;

  PROCEDURE pp_act_maestros IS
    v_fecha date;
  begin
    -- Actualizo el cheque que fue rechazado en la tabla fcclrec
    update cc_che_recibidos
       set cod_cau_devolucion = P_CAUSA, est_cheque = 'R'
     where fec_proceso = P_FECHA
       and cod_ofi_camara = v_cod_ofi_camara
       and nro_cuenta = v_nro_cuenta
       and nro_cheque = v_nro_cheque;
  
    if sql%notfound then
      raise_application_error(-20000,'No encontro registro en CC_CHE_RECIBIDOS ' ||sqlerrm);
    end if;
  
    if v_fec_actual = P_FECHA then
      v_fecha := PAG_CAL.FU_OBT_FEC_PROXIMA(4);
    else
      v_fecha := v_fec_actual;
    end if;
    -- Actualizo los cheques rechazados en la tabla de totales
    update cc_sal_camara
       set sis_che_dev_a_camara = nvl(sis_che_dev_a_camara, 0) +
                                  nvl(v_val_cheque, 0)
     where fecha = v_fecha
       and cod_moneda = v_cod_moneda
       and cod_ofi_camara = v_cod_ofi_camara;
    if sql%notfound then
      insert into cc_sal_camara
        (cod_ofi_camara, cod_moneda, fecha, sis_che_dev_a_camara)
      values
        (v_cod_ofi_camara, v_cod_moneda, v_fecha, v_val_cheque);
    end if;
  exception
    when others then
      raise_application_error(-20000, 'En cc_sal_camara ' || sqlerrm);
  end;

  PROCEDURE PP_CAL_MULTA(P_VAL_MULTA OUT NUMBER) IS
  
    v_cod_tra_multa    ge_movimientos.cod_transaccion%type;
    v_cod_tas_multa    ge_movimientos.cod_tasa%type;
    v_val_tas_multa    ge_movimientos.val_tasa%type;
    v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
    v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
    v_val_tas_impuesto ge_movimientos.val_tasa%type;
    v_val_impuesto     ge_movimientos.monto%type;
    ---
    v_val_exo_cargo    ge_movimientos.val_tasa%type;
    v_val_exo_impuesto ge_movimientos.val_tasa%type;
    v_tip_valor        ge_tasas.tip_valor%type;
    v_redondeo         NUMBER;  
  BEGIN
    --verificar si el motivo cobra multa
    v_cod_tra_multa := FUG_OBT_PARCAUSALES(P_CAUSA, 'COD_TRA_MULTA');
    if v_cod_tra_multa is not null then
       --sólo si ya no se le cobró multa, ya q se cobra una sóla vez por Insuf.de fondos
       --if FUC_VER_COB_MULTA(V_NRO_CUENTA, V_NRO_CHEQUE) = 'N' then
       prg_obt_cargos(P_COD_OFICINA,
                      V_NRO_CUENTA,
                      V_COD_MONEDA,
                      V_VAL_CHEQUE,
                      V_COD_MODULO,
                      V_COD_MODALIDAD,
                      V_COD_TRA_MULTA,
                      V_COD_TAS_MULTA,
                      V_VAL_TAS_MULTA,
                      P_VAL_MULTA,
                      V_COD_TRA_IMPUESTO,
                      V_COD_TAS_IMPUESTO,
                      V_VAL_TAS_IMPUESTO,
                      V_VAL_IMPUESTO);
       /*
       || PCC-Exoneración y Extorno de Comisiones y Tasas
       || Se ejecuta si el proceso no es mensual
       || o la base de datos no es producción
       */
       if FUC_VER_COB_MULTA(V_NRO_CUENTA, V_NRO_CHEQUE) = 'N' then
          begin
             v_val_exo_cargo := fug_obt_val_tasa(V_COD_MODULO,
                                                 V_COD_MODALIDAD,
                                                 P_COD_OFICINA,
                                                 null,
                                                 V_COD_MONEDA,
                                                 0, 'N', NULL,
                                                 V_COD_TRA_MULTA,
                                                 v_fec_actual);
          exception
             when others then
                raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
          end;
          v_tip_valor := fug_obt_tip_val_tasa(V_COD_TAS_MULTA);
          v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                            V_COD_MODULO,
                                            V_COD_MODALIDAD,
                                            V_COD_MONEDA);
          IF v_tip_valor = 'V' THEN
             -- si es un valor, se toma directamente
             v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
          ELSE
             -- es un porcentaje
             v_val_exo_cargo := round(nvl(V_VAL_CHEQUE, 0) * nvl(v_val_exo_cargo, 0) / 100, v_redondeo);
             --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
             v_val_exo_cargo := pag_gen.fu_obt_val_final(v_val_exo_cargo);
          END IF;          
          if pag_cta.fu_ver_tra_prohibida(V_NRO_CUENTA,
                                          V_COD_TRA_MULTA,
                                          V_COD_MODULO,
                                          V_COD_MODALIDAD) = 'S' then
             prg_ins_exoneracion(V_COD_TRA_MULTA, V_COD_MODULO,
                                 V_COD_MODALIDAD, V_COD_MONEDA,
                                 V_NRO_CUENTA, null, V_COD_TAS_MULTA,
                                 nvl(v_val_exo_cargo, 0),
                                 nvl(v_val_exo_cargo, 0), null,
                                 nvl(v_val_exo_cargo, 0));
          elsif ( nvl(P_VAL_MULTA, 0) <> nvl(v_val_exo_cargo, 0)) or
                ( nvl(P_VAL_MULTA, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0) then
             prg_ins_exoneracion(V_COD_TRA_MULTA, V_COD_MODULO,
                                 V_COD_MODALIDAD, V_COD_MONEDA,
                                 V_NRO_CUENTA, null, V_COD_TAS_MULTA,
                                 (nvl(v_val_exo_cargo, 0) - nvl(P_VAL_MULTA, 0)),
                                  v_val_exo_cargo, null,
                                 (nvl(v_val_exo_cargo, 0) - nvl(P_VAL_MULTA, 0)));
          end if;
          
          /*DYDMR-4018 Solamente si tiene definida la transaccion para impuesto (ALV-JUL/2016)*/
          if v_cod_tra_impuesto is not null then
            begin
               v_val_exo_impuesto := fug_obt_val_tasa(V_COD_MODULO,
                                                      V_COD_MODALIDAD,
                                                      P_COD_OFICINA,
                                                      null,
                                                      V_COD_MONEDA,
                                                      0, 'N', NULL,
                                                      v_cod_tra_impuesto,
                                                      v_fec_actual);
            exception
               when others then
                  raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
            end;
            IF v_tip_valor = 'V' THEN
               -- si es un valor, se toma directamente
               v_val_exo_impuesto := nvl(v_val_exo_impuesto, 0);
            ELSE
               -- es un porcentaje, se considera incluido en el cargo
               v_val_exo_impuesto := round(nvl(v_val_exo_cargo, 0) * nvl(v_val_exo_impuesto, 0) /
                                      (100 + v_val_exo_impuesto), v_redondeo);
               --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
               v_val_exo_impuesto := pag_gen.fu_obt_val_final(v_val_exo_impuesto);
            END IF;
            if pag_cta.fu_ver_tra_prohibida(V_NRO_CUENTA,
                                            v_cod_tra_impuesto,
                                            V_COD_MODULO,
                                            V_COD_MODALIDAD) = 'S' then
               prg_ins_exoneracion(v_cod_tra_impuesto, V_COD_MODULO,
                                   V_COD_MODALIDAD, V_COD_MONEDA,
                                   V_NRO_CUENTA, null, V_COD_TAS_IMPUESTO,
                                   nvl(v_val_exo_impuesto, 0),
                                   nvl(v_val_exo_impuesto, 0), null,
                                   nvl(v_val_exo_impuesto, 0));
            elsif pag_cta.fu_ver_tra_prohibida(V_NRO_CUENTA,
                                               V_COD_TRA_MULTA,
                                               V_COD_MODULO,
                                               V_COD_MODALIDAD) = 'S' then
               null;
            elsif ( nvl(v_val_impuesto, 0) <> nvl(v_val_exo_impuesto, 0) ) or
                  ( nvl(v_val_impuesto, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0 ) then
               prg_ins_exoneracion(v_cod_tra_impuesto, V_COD_MODULO,
                                   V_COD_MODALIDAD, V_COD_MONEDA,
                                   V_NRO_CUENTA, null, V_COD_TAS_IMPUESTO,
                                   (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)),
                                    v_val_exo_impuesto, null,
                                   (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)));
            end if;
          ---
          end if;             
       else
          prg_ins_exoneracion(V_COD_TRA_MULTA, V_COD_MODULO,
                              V_COD_MODALIDAD, V_COD_MONEDA,
                              V_NRO_CUENTA, null, V_COD_TAS_MULTA,
                              nvl(P_VAL_MULTA, 0),
                              nvl(P_VAL_MULTA, 0), null,
                              nvl(P_VAL_MULTA, 0));
          P_VAL_MULTA := 0;
       end if;
    end if;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'Calc.Multa ' || sqlerrm);
  END;

  PROCEDURE PP_ACT_CHE_DEVUELTOS IS
    v_redondeo        number;
    v_cod_usu_oficial ge_clientes.cod_usu_oficial%type;
    v_val_multa       number;
  begin
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                      4,
                                      v_cod_modalidad,
                                      v_cod_moneda);
  
    begin
      select cod_usu_oficial
        into v_cod_usu_oficial
        from ge_clientes
       where cod_persona in
             (select cod_persona
                from ge_cta_clientes
               where cod_modulo = 4
                 and nro_cuenta = v_nro_cuenta)
         and rownum <= 1;
    exception
      when others then
        raise_application_error(-20000,'Error al buscar el Gestor. ' || sqlerrm);
    end;
    PP_CAL_MULTA(V_VAL_MULTA);
    insert into CC_CHE_DEVUELTOS
      (FECHA,
       HORA,
       COD_USUARIO,
       NRO_CUENTA,
       NRO_CHEQUE,
       COD_MONEDA,
       MONTO,
       COD_CAUSA,
       MULTA,
       SAL_MULTA,
       COD_BCO_RECEPTOR,
       NRO_CAJA,
       COD_OFI_CAMARA,
       TIPO)
    values
      (v_fec_actual,
       v_hora,
       v_cod_usu_oficial,
       v_nro_cuenta,
       v_nro_cheque,
       v_cod_moneda,
       v_val_cheque,
       P_CAUSA,
       nvl(round(v_val_multa, v_redondeo), 0),
       nvl(round(v_val_multa, v_redondeo), 0),
       v_cod_bco_receptor,
       null,
       v_cod_ofi_camara,
       FUG_OBT_PARCAUSALES(P_CAUSA, 'TIP_DEVOLUCION'));
  
  exception
    when others then
      raise_application_error(-20000, ' en CC_CHE_DEVUELTOS ' || sqlerrm);
  end;

  PROCEDURE PP_ACTUALIZAR IS
  BEGIN
    PP_VERIFICAR_CHE_PROCESADOS;
  
    If v_nro_boleta is not null then
      PP_PRO_DEV_DEPOSITO;
    else
      -- transaccion que se graba si el cheque es rechazado al dia sgte.
      v_tra_rec_nex_dia := 631;
      if P_FECHA = v_fec_actual then
        -- devuelve la trans. :global.tranbco si el rechazo es del dia 
        pp_verifica_tipo_banco;
      end if;
    
      -- genera el movimiento en ge_movimientos por el credito a la cta.cte. o cta. ban.
      If v_compensacion = 'S' then
        pp_gen_movimiento(602, v_val_cheque, fug_obt_des_causa(P_CAUSA));
        pp_compensacion;
      
      else
        pp_gen_movimiento(v_tra_rec_nex_dia,
                          v_val_cheque,
                          fug_obt_des_causa(P_CAUSA));
      End if;
    
      If v_cod_modalidad = 41 then
        If v_che_cert = 'N' then
          update cc_cta_corrientes
             set fec_ult_movimiento = v_fec_actual,
                 hor_ult_movimiento = v_hora,
                 sal_total          = nvl(sal_total, 0) +
                                      nvl(v_val_cheque, 0)
           where nro_cuenta = v_nro_cuenta;
          If sql%notfound then
            raise_application_error(-20000,'Al actualizar CC_CTA_CORRIENTES ' ||sqlerrm);
          End if;
        else
          update cc_cta_bancarias
             set fec_ult_movimiento = v_fec_actual,
                 hor_ult_movimiento = v_hora,
                 sal_total          = nvl(sal_total, 0) +
                                      nvl(v_val_cheque, 0)
           where cod_modulo = 4
             and cod_modalidad = 44
             and nro_cuenta = v_cta_cert;
          If sql%notfound then
            raise_application_error(-20000,'Al actualizar CC_CTA_BANCARIAS 1 ' ||sqlerrm);
          End if;
        End if;
      else
        update cc_cta_bancarias
           set fec_ult_movimiento = v_fec_actual,
               hor_ult_movimiento = v_hora,
               sal_total          = nvl(sal_total, 0) + nvl(v_val_cheque, 0)
         where nro_cuenta = v_nro_cuenta;
        If sql%notfound then
          raise_application_error(-20000,'Al actualizar CC_CTA_BANCARIAS 2 ' ||sqlerrm);
        End if;
      End if;
    End if;
    --Actualizar el estado del cheque en cc_chequeras
    If v_che_cert = 'S' then
      pp_actualizar_estado_che('C');
    else
      --ver si es cuenta gerencia
      If v_cod_modalidad = 43 then
        pp_actualizar_estado_che('G');
      else
        pp_actualizar_estado_che('E');
      End if;
    End if;
    ---si es cheque certificado, desmarcar fecha de pago.
    if v_che_cert = 'S' then
      update cc_che_certificados
         set fec_pago = null, cod_cau_devolucion = P_CAUSA
       where nro_cuenta = v_nro_cuenta
         and nro_cheque = v_nro_cheque;
      If sql%notfound then
        raise_application_error(-20000,'Al actualizar CC_CHE_CERTIFICADOS ' ||sqlerrm);
      End if;
    end if;
    --si es cheque gerencia
    PP_VERIFICAR_CHE_GER(V_NRO_CHEQUE, V_NRO_CUENTA, V_VAL_CHEQUE);
    if v_che_gerencia = 'S' then
      update cc_che_ger_emitidos
         set fec_pago = null, cod_usu_pagador = null
       where nro_cheque = v_nro_cheque
         and nro_cuenta = v_nro_cuenta;
      If sql%notfound then
        raise_application_error(-20000,'Al actualizar CC_CHE_GER_EMTIDOS ' ||sqlerrm);
      End if;
    end if;
  
    update cc_che_pagados
       set cod_cau_devolucion = P_CAUSA
     where nro_cuenta = v_nro_cuenta
       and nro_cheque = v_nro_cheque
       and monto = v_val_cheque
       and fecha = (select max(fecha)
                      from cc_che_pagados b
                     where b.nro_cuenta = v_nro_cuenta
                       and b.nro_cheque = v_nro_cheque
                       and b.monto = v_val_cheque);
    If sql%notfound then
      null;
    End if;
  
    --solamene cuando son cheque devueltos a camara     
    If v_nro_boleta is null then
      pp_act_maestros;
    end if;
  
    pp_act_che_devueltos; -- ya genera la multa.
  
  exception
    when others then
      raise_application_error(-20000, sqlerrm);
  end;

BEGIN
  --> Proceso Principal
  For i in c_datos loop
    v_cod_ofi_camara := i.cod_ofi_camara;
    v_nro_cuenta     := i.nro_cuenta;
    v_nro_cheque     := i.nro_cheque;
    v_val_cheque     := i.valor;
    v_ind            := i.ind;
    v_cod_moneda     := i.cod_moneda;
    Begin
      select t.cod_modalidad
      into   v_cod_modalidad
      from ge_cuentas t
      where t.nro_cuenta = P_NRO_CUENTA;
    End;
    pp_val_est_cheque;
  
    pp_actualizar;
  
  End Loop;
EXCEPTION
  When Others Then
    raise_application_error(-20000,'Error en el proceso de rechazo de cheque ' ||sqlerrm);

END;
/

