CREATE OR REPLACE PACKAGE BODY IT.PAG_REC is
  g_fre_proceso VARCHAR2(1) := fug_obt_fre_proceso('PAG_REC.PR_COB_CARGOS');
  g_db_prod     VARCHAR2(1) := fug_ind_produccion;
  --- Inserta los errores en la tabla ge_pag_recaudaciones_err

  PROCEDURE PR_INS_LOG (RG_GPREC IN GE_PAG_RECAUDACIONES_ERR%ROWTYPE)
            IS
   v_existe varchar2(1) := 'N';
   v_hora varchar2(20);
   v_error varchar2(3000);
   v_cod_persona ba_personas.cod_persona%type;
  BEGIN
    -- comentado DDEVOLUT-99: la insercion en log de errores se hace por cada bloque 
    -- de validacion no cumplida. En forma detallada ya no agrupada
   
        --PCCDEEVO-498 Validar si es de tipo Seguros y es por Saldo Insuficiente de la Cuenta el rechazo
       if rg_gprec.tip_cobranza = 4 --Cobro de seguros
          and rg_gprec.msj_error like '%con Saldo Insuficiente p/ el debito de%' then
          --Llamar a nuevo Proceso para notificar al cliente PCCDEEVO-498
          --Si hubo error se guarda en Log.(Puede ser llamado desde el cierre)
          --Obtenemos el Codigo de Persona
          v_cod_persona:=null;
          begin
            select a.cod_persona
              into v_cod_persona
                from ge_cta_clientes a 
                  where a.nro_cuenta=rg_gprec.nro_cta_debito
                   and rownum=1;
          exception
            when no_data_found then
              v_cod_persona:=null;
            when others then
              v_cod_persona:=null;
          end;
          
          
          if v_cod_persona is not null then
            begin
               PRG_GEN_NOT_SEGUROS(v_cod_persona,
                                   rg_gprec.nro_cta_debito,
                                   'R',
                                   rg_gprec.cod_ente,
                                   null);
            exception
              when others then
                   v_hora:= to_char(sysdate,'hh24:mi:ss');
                   v_error:= substr(to_char(sqlerrm),1,3000);
                   INSERT INTO ge_ra_log_mail
                             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                   VALUES
                             (SYSDATE, rg_gprec.nro_cta_debito||' Ente:'||rg_gprec.cod_ente, 'ERROR', 'Pag_Rec -Not. Seguros.PJ. ', v_error,v_hora , v_hora); 

            end;
          end if;
          
       end if;
        insert into ge_pag_recaudaciones_err
         (cod_ente,
          nro_cta_debito,
          nro_cta_credito,
          fec_operacion,
          nro_archivo,
          monto,
          cod_error,
          msj_error,
          observacion,
          nro_factura,
          cod_moneda,
          tip_cobranza
          )
        values
         (rg_gprec.cod_ente,
          rg_gprec.nro_cta_debito,
          rg_gprec.nro_cta_credito,
          rg_gprec.fec_operacion,
          rg_gprec.nro_archivo,
          rg_gprec.monto,
          rg_gprec.cod_error,
          rg_gprec.msj_error,
          rg_gprec.observacion,
          rg_gprec.nro_factura,
          rg_gprec.cod_moneda,
          rg_gprec.tip_cobranza
          );
       -- comentado DDEVOLUT-99: la insercion en log de errores se hace por cada bloque 
       -- de validacion no cumplida. En forma detallada ya no agrupada
       /*else-- nuevo bloque que actualiza el campo monto de ge_pag_recaudaciones_err - re - 26/03/2015
           -- para cuadrar en la conciliacion entre CD y Archivo pag_servicios
           UPDATE ge_pag_recaudaciones_err e
           SET e.monto =  e.monto + nvl(rg_gprec.monto,0)
           WHERE e.cod_ente = RG_GPREC.COD_ENTE
             and e.fec_operacion = RG_GPREC.Fec_Operacion
             and e.nro_archivo = RG_GPREC.Nro_Archivo
             and e.nro_cta_debito = RG_GPREC.Nro_Cta_Debito
             and e.nro_cta_credito = RG_GPREC.Nro_Cta_Credito
             and nvl(e.tip_cobranza,'xx') = nvl(RG_GPREC.Tip_Cobranza,'xx')
             and e.cod_error = RG_GPREC.Cod_Error;

     end if; */
   exception
       when others then
         null;
  END;

  -- Obtiene el siguiente número de archivo para los registros a importar.
  FUNCTION FU_OBT_SIG_NUM_ARCHIVO(
                 P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE,
                 P_FEC_OPERACION IN GE_PAG_RECAUDACIONES.FEC_OPERACION%TYPE)
                 RETURN NUMBER IS
   v_sig_num_archivo number;
   v_sig_num_archivo_tmp number;
   Begin
     -- maxima secuencia procesada por fecha de operacion
     begin
      select max(nro_archivo)
        into v_sig_num_archivo
        from ge_pag_recaudaciones
       where cod_ente = p_cod_ente
         and fec_operacion = P_FEC_OPERACION;
       v_sig_num_archivo := nvl(v_sig_num_archivo,0) + 1;
     exception
       when no_data_found then
        v_sig_num_archivo := 1;
       when others then
        v_sig_num_archivo := 1;
     end;
     -- maxima secuencia en el temporal
     begin
      select max(nro_archivo)
        into v_sig_num_archivo_tmp
        from ge_pag_recaudaciones_tmp
       where cod_ente = p_cod_ente
         and fec_operacion = P_FEC_OPERACION;
       v_sig_num_archivo_tmp := nvl(v_sig_num_archivo_tmp,0) + 1;
     exception
       when no_data_found then
        v_sig_num_archivo_tmp := 1;
       when others then
        v_sig_num_archivo_tmp := 1;
     end;
     -- se retorna el maximo entre los dos
     if v_sig_num_archivo_tmp > v_sig_num_archivo then
        v_sig_num_archivo := v_sig_num_archivo_tmp;
     end if;
     -- maxima secuencia en la tabla de errores
     begin
      select max(nro_archivo)
        into v_sig_num_archivo_tmp
        from ge_pag_recaudaciones_err
       where cod_ente = p_cod_ente
         and fec_operacion = P_FEC_OPERACION;
       v_sig_num_archivo_tmp := nvl(v_sig_num_archivo_tmp,0) + 1;
     exception
       when no_data_found then
        v_sig_num_archivo_tmp := 1;
       when others then
        v_sig_num_archivo_tmp := 1;
     end;
     -- se retorna el maximo entre los dos
     if v_sig_num_archivo_tmp > v_sig_num_archivo then
        v_sig_num_archivo := v_sig_num_archivo_tmp;
     end if;

     -- maxima secuencia por dia
     begin
      select max(nro_archivo)
        into v_sig_num_archivo_tmp
        from ge_pag_recaudaciones
       where cod_ente = p_cod_ente
         and trunc(fec_insercion) = trunc(sysdate);
       v_sig_num_archivo_tmp := nvl(v_sig_num_archivo_tmp,0) + 1;
     exception
       when no_data_found then
        v_sig_num_archivo_tmp := 1;
       when others then
        v_sig_num_archivo_tmp := 1;
     end;
     if v_sig_num_archivo_tmp > v_sig_num_archivo then
        v_sig_num_archivo := v_sig_num_archivo_tmp;
     end if;
     -- maxima secuencia en el temporal
     begin
      select max(nro_archivo)
        into v_sig_num_archivo_tmp
        from ge_pag_recaudaciones_tmp
       where cod_ente = p_cod_ente
         and trunc(fec_insercion) = trunc(sysdate);
       v_sig_num_archivo_tmp := nvl(v_sig_num_archivo_tmp,0) + 1;
     exception
       when no_data_found then
        v_sig_num_archivo_tmp := 1;
       when others then
        v_sig_num_archivo_tmp := 1;
     end;
     -- se retorna el maximo entre los dos
     if v_sig_num_archivo_tmp > v_sig_num_archivo then
        v_sig_num_archivo := v_sig_num_archivo_tmp;
     end if;

     return (v_sig_num_archivo);
   End;

   --Valida los datos de la importación de datos.
   PROCEDURE PR_VAL_DATOS(P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE,
                          P_FECHA IN GE_CALENDARIOS.FEC_ACTUAL%TYPE,
                          P_NRO_ARCHIVO IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                          P_PROCESO IN VARCHAR2)
                          IS
   v_cod_mon_cta_cre ge_cuentas.cod_moneda%type;
   v_cod_mon_cta_deb ge_cuentas.cod_moneda%type;
   v_dia_pago number;
   v_dia_diferencia number;
   v_cta_recaudadora varchar2(1);
   v_cta_recaudadora_def varchar2(15);
   v_exi_cta_credito varchar2(1);
   v_exi_cta_debito varchar2(1);
   v_exi_cta_deb_rec varchar2(1);
   v_procesa_cre varchar2(1);
   v_procesa_deb varchar2(1);
   v_cod_modulo ge_modalidades.cod_modulo%type;
   v_cod_modalidad ge_modalidades.cod_modalidad%type;
   v_sal_disponible ge_cuentas.sal_contable%type;
   v_estado ge_cuentas.estado%type;
   v_cod_per_ente        ge_entes.cod_persona%type default fue_obt_per_ente(p_cod_ente);
   v_cta_existente       varchar2(1) default 'N';
   RG_GPREC ge_pag_recaudaciones_err%rowtype;
   CURSOR c_rec IS
      select t.nro_cta_credito, t.nro_cta_debito, t.cod_moneda, t.monto, t.fec_operacion,t.tip_cobranza, t.nro_factura
      from ge_pag_recaudaciones_tmp t
      where t.cod_ente = P_COD_ENTE
        and trunc(t.fec_insercion) <= P_FECHA
        and t.nro_archivo = P_NRO_ARCHIVO
        and P_PROCESO = 'N'
     UNION ALL --se modifico "UNION" por "UNION ALL" -- RE -26/03/2015
      select r.nro_cta_credito, r.nro_cta_debito, r.cod_moneda, r.monto, r.fec_operacion,r.tip_cobranza, r.nro_factura
      from ge_pag_recaudaciones r
      where r.cod_ente = P_COD_ENTE
        and trunc(r.fec_insercion) <= P_FECHA
        and r.nro_archivo = P_NRO_ARCHIVO
        and P_PROCESO = 'S';
   --Variables JIRA DE-672 ; RE - 26/03/2015
   v_hay_error BOOLEAN;  --verifica si hay error en el registro
   v_con_error NUMBER(3); --cuenta cantidad de errores
   v_msg_error ge_pag_recaudaciones_err.msj_error%TYPE; -- variable para agrupar los errores

   BEGIN
     for c in c_rec LOOP
       v_con_error := 0;
       v_hay_error := FALSE;
       v_msg_error := NULL;
        --Trae la cuenta de credito de la parametrizacion por entes
        if c.nro_cta_credito is null then
           v_cta_recaudadora_def := fug_obt_parentes(p_cod_ente, 'NRO_CTA_RECAUDADORA_'||c.cod_moneda);
        end if;
        --Verifica si existe la Cta. de Credito.
       begin
         select 'S'
           into v_exi_cta_credito
           from ge_cta_clientes cc
          where (cc.nro_cuenta = c.nro_cta_credito or cc.nro_cuenta = v_cta_recaudadora_def)
            and cc.relacion = 'P';
       exception
        when no_data_found then
           v_exi_cta_credito := 'N';
        when others then
           v_exi_cta_credito := 'N';
       end;
       if v_exi_cta_credito = 'N' then
            RG_GPREC.COD_ENTE := P_COD_ENTE;
            RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
            RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
            RG_GPREC.Fec_Operacion := c.fec_operacion;
            RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
            RG_GPREC.MONTO := c.monto;
            RG_GPREC.Nro_Factura := c.nro_factura;
            RG_GPREC.Cod_Moneda := c.cod_moneda;
            RG_GPREC.TIP_COBRANZA := c.tip_cobranza;
            v_con_error := v_con_error + 1;
            IF v_msg_error IS NULL THEN
               v_msg_error:= 'Nro.Cta.Crédito '||c.nro_cta_credito||' inexistente.';
            ELSE
               v_msg_error:= v_msg_error ||'; '||'Nro.Cta.Crédito '||c.nro_cta_credito||' inexistente.';
            END IF;
           -- RG_GPREC.COD_ERROR :=  v_con_error; -- 12;
           -- RG_GPREC.Msj_Error := 'Nro.Cta.Crédito '||c.nro_cta_credito||' inexistente.';
           -- pag_rec.PR_INS_LOG(RG_GPREC); -- RE - 26/03/2015

            --Verifica si es proceso de Pago o Importacion.

            if P_PROCESO = 'S' then
               update ge_pag_recaudaciones r
                 set r.estado = 'E'
                where r.cod_ente = P_COD_ENTE
                  and r.fec_operacion = P_FECHA
                  and r.nro_archivo = P_NRO_ARCHIVO
                  and r.nro_cta_debito = c.nro_cta_debito
                  and r.nro_cta_credito = c.nro_cta_credito;
            else
             update ge_pag_recaudaciones_tmp r
               set r.estado = 'E'
              where r.cod_ente = P_COD_ENTE
                and trunc(r.fec_insercion) = P_FECHA
                and r.nro_archivo = P_NRO_ARCHIVO
                and r.nro_cta_debito = c.nro_cta_debito
                and r.nro_cta_credito = c.nro_cta_credito;
            end if;
       end if;
      --Verifica si existe la Cta. Debito.
       begin
         select distinct 'S'
           into v_exi_cta_debito
           from ge_cta_clientes cc
          where cc.nro_cuenta = c.nro_cta_debito;
       exception
        when no_data_found then
           v_exi_cta_debito := 'N';
        when others then
           v_exi_cta_debito := 'N';
       end;
       if v_exi_cta_debito = 'N' then
            RG_GPREC.COD_ENTE := P_COD_ENTE;
            RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
            RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
            RG_GPREC.Fec_Operacion := c.fec_operacion;
            RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
            RG_GPREC.MONTO := c.monto;
            RG_GPREC.NRO_FACTURA := c.nro_factura;
            RG_GPREC.Cod_Moneda := c.cod_moneda;
            RG_GPREC.TIP_COBRANZA := c.tip_cobranza;
            v_con_error := v_con_error + 1;
            IF v_msg_error IS NULL THEN
               v_msg_error:= 'Nro.Cta.Débito '||c.nro_cta_debito||' inexistente.';
            ELSE
               v_msg_error:= v_msg_error ||'; '||'Nro.Cta.Débito '||c.nro_cta_debito||' inexistente.';
            END IF;
            --RG_GPREC.COD_ERROR :=  v_con_error; --12;
            --RG_GPREC.Msj_Error := 'Nro.Cta.Debito '||c.nro_cta_debito||' inexistente.';
            --pag_rec.PR_INS_LOG(RG_GPREC); -- RE - 26/03/2015

            --Verifica si es proceso de Pago o Importacion.

            if P_PROCESO = 'S' then
               update ge_pag_recaudaciones r
                 set r.estado = 'E'
                where r.cod_ente = P_COD_ENTE
                  and r.fec_operacion = P_FECHA
                  and r.nro_archivo = P_NRO_ARCHIVO
                  and r.nro_cta_debito = c.nro_cta_debito
                  and r.nro_cta_credito = c.nro_cta_credito;
            else
               update ge_pag_recaudaciones_tmp r
               set r.estado = 'E'
              where r.cod_ente = P_COD_ENTE
                and trunc(r.fec_insercion) = P_FECHA
                and r.nro_archivo = P_NRO_ARCHIVO
                and r.nro_cta_debito = c.nro_cta_debito
                and r.nro_cta_credito = c.nro_cta_credito;
            end if;
       end if;
        if v_exi_cta_credito = 'N' OR v_exi_cta_debito = 'N' THEN -- RE - 26/03/2015
          RG_GPREC.COD_ERROR := v_con_error;
          RG_GPREC.Msj_Error := v_msg_error;
          pag_rec.PR_INS_LOG(RG_GPREC);
        END IF;

       if v_exi_cta_credito = 'S' and v_exi_cta_debito = 'S' then
           --valida cuentas de credito.
           pag_cta.PR_OBT_CUENTA(nvl(c.nro_cta_credito,v_cta_recaudadora_def));
           pag_cta.PR_VER_OPERACION(nvl(c.nro_cta_credito,v_cta_recaudadora_def),
                                    fug_obt_parentes(p_cod_ente, 'COD_TRA_PADRE'),
                                    pag_cta.g_ctas.cod_modulo,
                                    pag_cta.g_ctas.COD_MODALIDAD,
                                    'C',
                                    c.cod_moneda,
                                    0,
                                    pag_cta.G_CTAS.COD_OFICINA,
                                    v_cod_modulo,
                                    v_cod_modalidad,
                                    v_estado,
                                    v_sal_disponible,
                                    v_procesa_cre,
                                    null);
           pag_cta.PR_VER_OPERACION(nvl(c.nro_cta_credito,v_cta_recaudadora_def),
                                    fug_obt_parentes(p_cod_ente, 'COD_TRA_PADRE'),
                                    pag_cta.g_ctas.cod_modulo,
                                    pag_cta.g_ctas.COD_MODALIDAD,
                                    'C',
                                    c.cod_moneda,
                                    0,
                                    pag_cta.G_CTAS.COD_OFICINA,
                                    v_cod_modulo,
                                    v_cod_modalidad,
                                    v_estado,
                                    v_sal_disponible,
                                    v_procesa_deb,
                                    null);
              if v_procesa_cre = 'S' and v_procesa_deb = 'S' then
                    --Verifica si la Cta. Credito corresponde al ente ingresado
                    begin
                      select distinct 'S'
                        into v_cta_existente
                        from ge_cta_clientes a
                       where a.cod_persona = v_cod_per_ente
                         and (a.nro_cuenta  = c.nro_cta_credito or a.nro_cuenta = v_cta_recaudadora_def);
                    exception
                      when no_data_found then
                        v_cta_existente := 'N';
                      when others then
                        v_cta_existente := 'N';
                    end;

                    if v_cta_existente = 'N' then
                       RG_GPREC.COD_ENTE := P_COD_ENTE;
                       RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
                       RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
                       RG_GPREC.Fec_Operacion := c.fec_operacion;
                       RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
                       RG_GPREC.MONTO := c.monto;
                       RG_GPREC.NRO_FACTURA := c.nro_factura;
                       RG_GPREC.Cod_Moneda := c.cod_moneda;
                       RG_GPREC.TIP_COBRANZA := c.tip_cobranza;
                       v_con_error := v_con_error + 1;
                       IF v_msg_error IS NULL THEN
                          v_msg_error:= 'Nro.Cta.Crédito '||c.nro_cta_credito||' no corresponde al ente.';
                       ELSE
                          v_msg_error:= v_msg_error ||'; '||'Nro.Cta.Crédito '||c.nro_cta_credito||' no corresponde al ente.';
                       END IF;
                       --RG_GPREC.COD_ERROR := 789;
                       --RG_GPREC.Msj_Error := 'Nro.Cta.Credito '||c.nro_cta_credito||' no corresponde al ente.';
                       --pag_rec.PR_INS_LOG(RG_GPREC); -- RE - 26/03/2015
                       v_hay_error := TRUE;

                        --Verifica si es proceso de Pago o Importacion.

                        if P_PROCESO = 'S' then
                           update ge_pag_recaudaciones r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and r.fec_operacion = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        else
                           update ge_pag_recaudaciones_tmp r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and trunc(r.fec_insercion) = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        end if;
                    end if;
                    --verifica si la cuenta de credito es recaudadora.
                   begin
                     select a.val_parametro
                      into v_cta_recaudadora
                      from ge_cta_dat_adicionales a
                      where (a.nro_cuenta = c.nro_cta_credito or a.nro_cuenta = v_cta_recaudadora_def)
                        and a.parametro = 'CTA_CRE_RECAUDADORA';
                   exception
                    when no_data_found then
                         v_cta_recaudadora := 'N';
                    when others then
                         v_cta_recaudadora := 'N';
                   end;
                   if v_cta_recaudadora = 'N' then
                        RG_GPREC.COD_ENTE := P_COD_ENTE;
                        RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
                        RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
                        RG_GPREC.Fec_Operacion := c.fec_operacion;
                        RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
                        RG_GPREC.MONTO := c.monto;
                        RG_GPREC.Nro_Factura := c.nro_factura;
                        RG_GPREC.Cod_Moneda := c.cod_moneda;
                        RG_GPREC.TIP_COBRANZA := c.tip_cobranza;                        
                        v_con_error := v_con_error + 1;
                        IF v_msg_error IS NULL THEN
                           v_msg_error:= 'Nro.Cta.Crédito '||nvl(c.nro_cta_credito,v_cta_recaudadora_def)||' no es recaudadora.';
                        ELSE
                           v_msg_error:= v_msg_error ||'; '||'Nro.Cta.Crédito '||nvl(c.nro_cta_credito,v_cta_recaudadora_def)||' no es recaudadora.';
                        END IF;
                        --RG_GPREC.COD_ERROR := 567;
                        --RG_GPREC.Msj_Error := 'Nro.Cta.Credito '||nvl(c.nro_cta_credito,v_cta_recaudadora_def)||' no es recaudadora.';
                        --pag_rec.PR_INS_LOG(RG_GPREC);--RE - 26/03/2015
                        v_hay_error := TRUE;

                        --Verifica si es proceso de Pago o Importacion.

                        if P_PROCESO = 'S' then
                           update ge_pag_recaudaciones r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and r.fec_operacion = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        else
                           update ge_pag_recaudaciones_tmp r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and trunc(r.fec_insercion) = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        end if;
                   end if;
                    --verifica si esta definido las cuentas de debitos en la tabla ge_cta_deb_recaudaciones
                   begin
                     select distinct 'S'
                       into v_exi_cta_deb_rec
                      from ge_cta_deb_recaudaciones r
                      where r.nro_cta_debito = c.nro_cta_debito
                        and r.cod_ente = P_COD_ENTE
                        and r.activo = 'S';
                   exception
                     when no_data_found then
                        v_exi_cta_deb_rec := 'N';
                     when others then
                        v_exi_cta_deb_rec := 'N';
                   end;
                   if v_exi_cta_deb_rec = 'N' then
                        RG_GPREC.COD_ENTE := P_COD_ENTE;
                        RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
                        RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
                        RG_GPREC.Fec_Operacion := c.fec_operacion;
                        RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
                        RG_GPREC.MONTO := c.monto;
                        RG_GPREC.Nro_Factura := c.nro_factura;
                        RG_GPREC.Cod_Moneda := c.cod_moneda;
                        RG_GPREC.TIP_COBRANZA := c.tip_cobranza;
                        v_con_error := v_con_error + 1;
                        IF v_msg_error IS NULL THEN
                           v_msg_error:= 'Nro.Cta.Débito '||c.nro_cta_debito||' no definida como cuenta de débito para el ente.';
                        ELSE
                           v_msg_error:= v_msg_error ||'; '||'Nro.Cta.Débito '||c.nro_cta_debito||' no definida como cuenta de débito para el ente.';
                        END IF;
                        --RG_GPREC.COD_ERROR := 101;
                        --RG_GPREC.Msj_Error := 'Nro.Cta.Debito '||c.nro_cta_debito||' no definida como cuenta de debito para el ente.';
                        --pag_rec.PR_INS_LOG(RG_GPREC);RE - 26/03/2015
                        v_hay_error := TRUE;

                        --Verifica si es proceso de Pago o Importacion.

                        if P_PROCESO = 'S' then
                           update ge_pag_recaudaciones r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and r.fec_operacion = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        else
                           update ge_pag_recaudaciones_tmp r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and trunc(r.fec_insercion) = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        end if;
                   end if;
                    if c.nro_cta_credito is not null then
                       v_cod_mon_cta_cre := fug_obt_mon_cta(c.nro_cta_credito);
                    else
                       v_cod_mon_cta_cre := fug_obt_mon_cta(v_cta_recaudadora_def);
                    end if;
                     v_cod_mon_cta_deb := fug_obt_mon_cta(c.nro_cta_debito);
                     --verifica moneda entre cuentas de debito y credito.
                     if v_cod_mon_cta_cre <> v_cod_mon_cta_deb THEN
                        RG_GPREC.COD_ENTE := P_COD_ENTE;
                        RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
                        RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
                        RG_GPREC.Fec_Operacion := c.fec_operacion;
                        RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
                        RG_GPREC.MONTO := c.monto;
                        RG_GPREC.NRO_FACTURA := c.nro_factura;
                        RG_GPREC.Cod_Moneda := c.cod_moneda;
                        RG_GPREC.TIP_COBRANZA := c.tip_cobranza;
                        v_con_error := v_con_error + 1;
                        IF v_msg_error IS NULL THEN
                           v_msg_error:= 'Moneda incorrecta';
                        ELSE
                           v_msg_error:= v_msg_error ||'; '||'Moneda incorrecta';
                        END IF;
                        --RG_GPREC.COD_ERROR := 123;
                        --RG_GPREC.Msj_Error := 'Moneda incorrecta';
                        --pag_rec.PR_INS_LOG(RG_GPREC); --RE - 26/03/2015
                        v_hay_error := TRUE;

                        --Verifica si es proceso de Pago o Importacion.

                        if P_PROCESO = 'S' then
                           update ge_pag_recaudaciones r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and r.fec_operacion = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        else
                           update ge_pag_recaudaciones_tmp r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and trunc(r.fec_insercion) = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        end if;
                     end if;
                    --verifica que el monto a importar sea mayor a 0.
                    if c.monto <= 0 THEN
                          RG_GPREC.COD_ENTE := P_COD_ENTE;
                          RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
                          RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
                          RG_GPREC.Fec_Operacion := c.fec_operacion;
                          RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
                          RG_GPREC.MONTO := c.monto;
                          RG_GPREC.NRO_FACTURA := c.nro_factura;
                          RG_GPREC.Cod_Moneda := c.cod_moneda;
                          RG_GPREC.TIP_COBRANZA := c.tip_cobranza;
                          v_con_error := v_con_error + 1;
                          IF v_msg_error IS NULL THEN
                             v_msg_error:= 'Monto no mayor a cero.';
                          ELSE
                             v_msg_error:= v_msg_error ||'; '||'Monto no mayor a cero.';
                          END IF;
                          --RG_GPREC.COD_ERROR := 345;
                          --RG_GPREC.Msj_Error := 'Monto no mayor a cero.';
                          --pag_rec.PR_INS_LOG(RG_GPREC); --RE - 26/03/2015
                          v_hay_error := TRUE;

                          --Verifica si es proceso de Pago o Importacion.

                          if P_PROCESO = 'S' then
                             update ge_pag_recaudaciones r
                               set r.estado = 'E'
                              where r.cod_ente = P_COD_ENTE
                                and r.fec_operacion = P_FECHA
                                and r.nro_archivo = P_NRO_ARCHIVO
                                and r.nro_cta_debito = c.nro_cta_debito
                                and r.nro_cta_credito = c.nro_cta_credito;
                          else
                             update ge_pag_recaudaciones_tmp r
                               set r.estado = 'E'
                              where r.cod_ente = P_COD_ENTE
                                and trunc(r.fec_insercion) = P_FECHA
                                and r.nro_archivo = P_NRO_ARCHIVO
                                and r.nro_cta_debito = c.nro_cta_debito
                                and r.nro_cta_credito = c.nro_cta_credito;
                          end if;
                   end if;
                   -- 02/08 Se valida que Inserte Tipo de Cobranza
                    if c.tip_cobranza is null THEN
                          RG_GPREC.COD_ENTE := P_COD_ENTE;
                          RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
                          RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
                          RG_GPREC.Fec_Operacion := c.fec_operacion;
                          RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
                          RG_GPREC.MONTO := c.monto;
                          RG_GPREC.NRO_FACTURA := c.nro_factura;
                          RG_GPREC.Cod_Moneda := c.cod_moneda;
                          RG_GPREC.TIP_COBRANZA := c.tip_cobranza;
                          v_con_error := v_con_error + 1;
                          IF v_msg_error IS NULL THEN
                             v_msg_error:= 'Tipo de Cobranza No Ingresado.';
                          ELSE
                             v_msg_error:= v_msg_error ||'; '||'Tipo de Cobranza No Ingresado.';
                          END IF;
                          v_hay_error := TRUE;
                         --Verifica si es proceso de Pago o Importacion.
                         if P_PROCESO = 'S' then
                             update ge_pag_recaudaciones r
                               set r.estado = 'E'
                              where r.cod_ente = P_COD_ENTE
                                and r.fec_operacion = P_FECHA
                                and r.nro_archivo = P_NRO_ARCHIVO
                                and r.nro_cta_debito = c.nro_cta_debito
                                and r.nro_cta_credito = c.nro_cta_credito;
                          else
                             update ge_pag_recaudaciones_tmp r
                               set r.estado = 'E'
                              where r.cod_ente = P_COD_ENTE
                                and trunc(r.fec_insercion) = P_FECHA
                                and r.nro_archivo = P_NRO_ARCHIVO
                                and r.nro_cta_debito = c.nro_cta_debito
                                and r.nro_cta_credito = c.nro_cta_credito;
                          end if;
                   end if;
                   --verifica si supero la cantidad de dia de pago.
                   v_dia_pago := fug_obt_parentes(p_cod_ente,'CAN_DIA_PAGO');
                   v_dia_diferencia := (pag_cal.FU_OBT_FEC_ACTUAL(1) - c.fec_operacion);
                   if abs(v_dia_diferencia) > v_dia_pago then
                        RG_GPREC.COD_ENTE := P_COD_ENTE;
                        RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
                        RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
                        RG_GPREC.Fec_Operacion := c.fec_operacion;
                        RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
                        RG_GPREC.MONTO := c.monto;
                        RG_GPREC.NRO_FACTURA := c.nro_factura;
                        RG_GPREC.Cod_Moneda := c.cod_moneda;
                        RG_GPREC.TIP_COBRANZA := c.tip_cobranza;
                        v_con_error := v_con_error + 1;
                        IF v_msg_error IS NULL THEN
                           v_msg_error:= 'Periodo de tiempo entre la fecha actual y la fecha de pago no debe superar '||v_dia_pago||' dias.';
                        ELSE
                           v_msg_error:= v_msg_error ||'; '||'Periodo de tiempo entre la fecha actual y la fecha de pago no debe superar '||v_dia_pago||' dias.';
                        END IF;
                        --RG_GPREC.COD_ERROR := 456;
                        --RG_GPREC.Msj_Error := 'Periodo de tiempo entre la fecha actual y la fecha de pago no debe superar '||v_dia_pago||' dias.';
                        --pag_rec.PR_INS_LOG(RG_GPREC); --RE - 26/03/2015
                        v_hay_error := TRUE;

                        --Verifica si es proceso de Pago o Importacion.

                        if P_PROCESO = 'S' then
                           update ge_pag_recaudaciones r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and r.fec_operacion = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        else
                           update ge_pag_recaudaciones_tmp r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and trunc(r.fec_insercion) = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        end if;
                   end if;
                   --verifica si la fec_operacion es menor a la fecha actual
                   if c.fec_operacion < pag_cal.FU_OBT_FEC_ACTUAL(1) then
                        RG_GPREC.COD_ENTE := P_COD_ENTE;
                        RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
                        RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
                        RG_GPREC.Fec_Operacion := c.fec_operacion;
                        RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
                        RG_GPREC.MONTO := c.monto;
                        RG_GPREC.NRO_FACTURA := c.nro_factura;
                        RG_GPREC.Cod_Moneda := c.cod_moneda;
                        RG_GPREC.TIP_COBRANZA := c.tip_cobranza;
                        v_con_error := v_con_error + 1;
                        IF v_msg_error IS NULL THEN
                           v_msg_error:= 'Fecha operación no debe de ser menor a la fecha actual del sistema.';
                        ELSE
                           v_msg_error:= v_msg_error ||'; '||'Fecha operación no debe de ser menor a la fecha actual del sistema.';
                        END IF;
                        --RG_GPREC.COD_ERROR :=  987;
                        --RG_GPREC.Msj_Error := 'Fecha operacion no debe de ser menor a la fecha actual del sistema.';
                        --pag_rec.PR_INS_LOG(RG_GPREC); --RE - 26/03/2015
                        v_hay_error := TRUE;

                        --Verifica si es proceso de Pago o Importacion.

                        if P_PROCESO = 'S' then
                           update ge_pag_recaudaciones r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and r.fec_operacion = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        else
                           update ge_pag_recaudaciones_tmp r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and trunc(r.fec_insercion) = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        end if;
                   end if;
                   --verifica si la fecha es habil
                   if pag_cal.fu_obt_fec_habil(c.fec_operacion, 1, NULL) != c.fec_operacion then
                        RG_GPREC.COD_ENTE := P_COD_ENTE;
                        RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
                        RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
                        RG_GPREC.Fec_Operacion := c.fec_operacion;
                        RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
                        RG_GPREC.MONTO := c.monto;
                        RG_GPREC.NRO_FACTURA := c.nro_factura;
                        RG_GPREC.Cod_Moneda := c.cod_moneda;
                        RG_GPREC.TIP_COBRANZA := c.tip_cobranza;
                        v_con_error := v_con_error + 1;
                        IF v_msg_error IS NULL THEN
                           v_msg_error:= 'Fecha de operación no es una fecha hábil para realizar la operación.';
                        ELSE
                           v_msg_error:= v_msg_error ||'; '||'Fecha de operación no es una fecha hábil para realizar la operación.';
                        END IF;
                        --RG_GPREC.COD_ERROR := 876;
                        --RG_GPREC.Msj_Error := 'Fecha de operacion no es una fecha habil para realizar la operacion.';
                        --pag_rec.PR_INS_LOG(RG_GPREC); --RE - 26/03/2015
                        v_hay_error := TRUE;

                        --Verifica si es proceso de Pago o Importacion.

                        if P_PROCESO = 'S' then
                           update ge_pag_recaudaciones r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and r.fec_operacion = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        else
                           update ge_pag_recaudaciones_tmp r
                             set r.estado = 'E'
                            where r.cod_ente = P_COD_ENTE
                              and trunc(r.fec_insercion) = P_FECHA
                              and r.nro_archivo = P_NRO_ARCHIVO
                              and r.nro_cta_debito = c.nro_cta_debito
                              and r.nro_cta_credito = c.nro_cta_credito;
                        end if;
                   end if;
              IF v_hay_error THEN   -- RE - 26/03/2015
                RG_GPREC.COD_ERROR := v_con_error;
                RG_GPREC.Msj_Error := v_msg_error;
                pag_rec.PR_INS_LOG(RG_GPREC);
              END IF;
            else
                RG_GPREC.COD_ENTE := P_COD_ENTE;
                RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
                RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
                RG_GPREC.Fec_Operacion := c.fec_operacion;
                RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
                RG_GPREC.MONTO := c.monto;
                RG_GPREC.NRO_FACTURA := c.nro_factura;
                RG_GPREC.Cod_Moneda := c.cod_moneda;
                RG_GPREC.TIP_COBRANZA := c.tip_cobranza;
                RG_GPREC.COD_ERROR := -100; --pag_cta.FU_OBT_COD_ERROR; -- RE - 26/03/2015
                RG_GPREC.Msj_Error := pag_cta.FU_OBT_COD_ERROR||'-'||pag_cta.FU_OBT_MSJ_ERROR;
                pag_rec.PR_INS_LOG(RG_GPREC);
                if P_PROCESO = 'S' then
                   update ge_pag_recaudaciones r
                     set r.estado = 'E'
                    where r.cod_ente = P_COD_ENTE
                      and r.fec_operacion = P_FECHA
                      and r.nro_archivo = P_NRO_ARCHIVO
                      and r.nro_cta_debito = c.nro_cta_debito
                      and r.nro_cta_credito = c.nro_cta_credito;
                else
                   update ge_pag_recaudaciones_tmp r
                     set r.estado = 'E'
                    where r.cod_ente = P_COD_ENTE
                      and trunc(r.fec_insercion) = P_FECHA
                      and r.nro_archivo = P_NRO_ARCHIVO
                      and r.nro_cta_debito = c.nro_cta_debito
                      and r.nro_cta_credito = c.nro_cta_credito;
                end if;
            end if;
         end if;
      end loop;
   END;

   --Obtener datos de los parametros.
   PROCEDURE PR_OBT_DAT_SERVICIOS(P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE,
                                  P_NRO_CTA_DEBITO IN GE_PAG_RECAUDACIONES.NRO_CTA_DEBITO%TYPE default null,
                                  P_NRO_ARCHIVO IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                                  P_FEC_OPERACION IN GE_PAG_RECAUDACIONES.FEC_OPERACION%TYPE,
                                  P_SER_COSTO IN OUT VARCHAR2,
                                  P_FEC_INI_CONTRATO IN OUT DATE,
                                  P_FEC_FIN_CONTRATO IN OUT DATE,
                                  P_CTA_RECAUDADORA_GS IN OUT VARCHAR2,
                                  P_CTA_RECAUDADORA_USD IN OUT VARCHAR2,
                                  P_CTA_RECAUDADORA_EUR IN OUT VARCHAR2,
                                  P_COD_TRA_PADRE IN OUT VARCHAR2,
                                  P_SER_ACTIVO IN OUT VARCHAR2,
                                  P_CAN_DIA_PAGO IN OUT VARCHAR2)
                                  IS
   v_exi_cta_rec_gs varchar2(1);
   v_exi_cta_rec_usd varchar2(1);
   v_exi_cta_rec_eur varchar2(1);
   RG_GPREC ge_pag_recaudaciones_err%rowtype;
   BEGIN
     P_SER_COSTO := fug_obt_parentes(P_COD_ENTE, 'COD_TAS_COSTO');
     P_FEC_INI_CONTRATO := to_date(fug_obt_parentes(p_cod_ente, 'FEC_INI_CONTRATO'),'dd/mm/yyyy');
     P_FEC_FIN_CONTRATO := to_date(fug_obt_parentes(p_cod_ente, 'FEC_FIN_CONTRATO'),'dd/mm/yyyy');
     P_CTA_RECAUDADORA_GS := fug_obt_parentes(p_cod_ente, 'NRO_CTA_RECAUDADORA_GS');
     if P_CTA_RECAUDADORA_GS is not null then
       begin
          select 'S'
            into v_exi_cta_rec_gs
           from ge_cuentas cu
           where cu.nro_cuenta = P_CTA_RECAUDADORA_GS
            and cu.cod_moneda = 'GS';
       exception
          when no_data_found then
             v_exi_cta_rec_gs := 'N';
          when others then
             v_exi_cta_rec_gs := 'N';
       end;
       if v_exi_cta_rec_gs = 'N' then
              RG_GPREC.COD_ENTE := P_COD_ENTE;
              RG_GPREC.Nro_Cta_Credito := P_CTA_RECAUDADORA_GS;
              RG_GPREC.NRO_CTA_DEBITO := nvl(P_NRO_CTA_DEBITO, P_CTA_RECAUDADORA_GS);
              RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO ;
              RG_GPREC.FEC_OPERACION := P_FEC_OPERACION;
              RG_GPREC.COD_ERROR := 12;
              RG_GPREC.Msj_Error := 'Nro. Cta. Recaudadora '||P_CTA_RECAUDADORA_GS||' no corresponde a la moneda GS.';
              pag_rec.PR_INS_LOG(RG_GPREC);
       end if;
     end if;

     P_CTA_RECAUDADORA_USD := fug_obt_parentes(p_cod_ente, 'NRO_CTA_RECAUDADORA_USD');
     if P_CTA_RECAUDADORA_USD is not null then
       begin
          select 'S'
            into v_exi_cta_rec_usd
           from ge_cuentas cu
           where cu.nro_cuenta = P_CTA_RECAUDADORA_USD
            and cu.cod_moneda = 'USD';
       exception
          when no_data_found then
             v_exi_cta_rec_usd := 'N';
          when others then
             v_exi_cta_rec_usd := 'N';
       end;
       if v_exi_cta_rec_usd = 'N' then
              RG_GPREC.COD_ENTE := P_COD_ENTE;
              RG_GPREC.Nro_Cta_Credito := P_CTA_RECAUDADORA_USD;
              RG_GPREC.NRO_CTA_DEBITO := nvl(P_NRO_CTA_DEBITO, P_CTA_RECAUDADORA_GS);
              RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
              RG_GPREC.FEC_OPERACION := P_FEC_OPERACION;
              RG_GPREC.COD_ERROR := 12;
              RG_GPREC.Msj_Error := 'Nro. Cta. Recaudadora '||P_CTA_RECAUDADORA_USD||' no corresponde a la moneda USD.';
              pag_rec.PR_INS_LOG(RG_GPREC);
       end if;
     end if;

     P_CTA_RECAUDADORA_EUR := fug_obt_parentes(p_cod_ente, 'NRO_CTA_RECAUDADORA_EUR');
     if P_CTA_RECAUDADORA_EUR is not null then
       begin
          select 'S'
            into v_exi_cta_rec_eur
           from ge_cuentas cu
           where cu.nro_cuenta = P_CTA_RECAUDADORA_EUR
            and cu.cod_moneda = 'EUR';
       exception
          when no_data_found then
             v_exi_cta_rec_eur := 'N';
          when others then
             v_exi_cta_rec_eur := 'N';
       end;
       if v_exi_cta_rec_eur = 'N' then
              RG_GPREC.COD_ENTE := P_COD_ENTE;
              RG_GPREC.Nro_Cta_Credito := P_CTA_RECAUDADORA_EUR;
              RG_GPREC.NRO_CTA_DEBITO := nvl(P_NRO_CTA_DEBITO, P_CTA_RECAUDADORA_GS);
              RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
              RG_GPREC.FEC_OPERACION := P_FEC_OPERACION;
              RG_GPREC.COD_ERROR := 12;
              RG_GPREC.Msj_Error := 'Nro. Cta. Recaudadora '||P_CTA_RECAUDADORA_EUR||' no corresponde a la moneda EUR.';
              pag_rec.PR_INS_LOG(RG_GPREC);
       end if;
     end if;

     P_COD_TRA_PADRE := fug_obt_parentes(p_cod_ente, 'COD_TRA_PADRE');
     P_SER_ACTIVO := fug_obt_parentes(p_cod_ente, 'SER_ACTIVO_SR');
     P_CAN_DIA_PAGO := fug_obt_parentes(p_cod_ente, 'CAN_DIA_PAGO');
   END;

   FUNCTION LF_VAL_CTA_ENTE(P_COD_ENTE GE_ENTES.COD_ENTE%TYPE,
                            P_NRO_CUENTA GE_CUENTAS.NRO_CUENTA%TYPE)
   RETURN VARCHAR2
   IS
   v_cod_per_ente        ge_entes.cod_persona%type default fue_obt_per_ente(p_cod_ente);
   v_cta_existente       varchar2(1) default 'N';
   v_val_cta_recaudadora varchar2(1) default 'N';
   BEGIN
     begin
       select distinct 'S'
         into v_cta_existente
         from ge_cta_clientes a
        where a.cod_persona = v_cod_per_ente
          and a.nro_cuenta  = p_nro_cuenta;
     exception
       when no_data_found then
         v_cta_existente := 'N';
       when others then
         v_cta_existente := 'N';
     end;
     if v_cta_existente = 'S' then
       v_val_cta_recaudadora := fug_obt_paradicional(p_nro_cuenta,'CTA_CRE_RECAUDADORA');
       if nvl(v_val_cta_recaudadora,'N') = 'S' then
         return 'S';
       else
         return 'N';
       end if;
     else
       return 'N';
     end if;
   END;
--Para_envio de mail de cobranzas de seguros
PROCEDURE LP_ENV_MAIL_CIE(p_cod_ente IN ge_entes.cod_ente%TYPE DEFAULT NULL,
  p_cod_moneda in ba_monedas.cod_moneda%type) IS

  v_fec_actual       date default pag_cal.fu_obt_fec_actual(1);
  v_fec_anterior     date default pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.fu_obt_fec_actual(1),7);
  v_cod_per_credito ge_cta_clientes.cod_persona%type;
  v_cod_per_debito ge_cta_clientes.cod_persona%type;
  v_nom_ente        ge_entes.descripcion%type;
  v_dir_mail_cre    varchar2(300);--ba_personas.dir_correo%type;
  v_nom_cli_debito  ba_personas.nom_completo%type;

  v_texto         varchar2(1000);
  v_texto_detalle clob;
  v_texto_detalle2 clob;
  v_adjunto       clob;
  v_adjunto_error clob;
  v_cabecera      clob;
  v_nom_adj varchar2(500);
  v_total_procesado number ;
  v_total_error number ;
  v_nro_registro number(20);

  v_tot_procesado varchar2(100);
  v_tot_error varchar2(100);

  -- Variables para mail
  v_conn     utl_smtp.connection;
  v_asunto   VARCHAR2(2000);
  v_mje_mail LONG;
  v_db_name  VARCHAR2(20);

  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;
  --
  v_can_normal      number(10):=0;
  v_can_error       number(10):=0;
  v_pie_normal      varchar2(30000);
  v_pie_error       varchar2(30000);
  v_nro_cta_credito varchar2(50);
  v_nro_cta_debito  varchar2(50);
  v_nro_archivo     varchar2(10);
  v_nro_factura     varchar2(300);
  v_tip_cobranza    varchar2(10);
  v_insertar        varchar2(1):='N';
  v_cod_ent_mov_pen varchar2(30);
  v_concepto        varchar2(300);

  --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  v_membrete LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P',c_dir_mail);
  --

  CURSOR g_ente is
     --Para envio en Lote
      select distinct(to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1)))) cod_ente,
      a.cod_moneda
       from ge_mov_pen_cobranzas a
         where a.fec_cobro = v_fec_actual
            and a.estado = 'P'
            and nvl(a.cierre,'N')='S'
            and (to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))))=p_cod_ente
            and a.cod_moneda= p_cod_moneda;
            --and a.concepto like '%Cobranza de Seguros.%';

  CURSOR c_rec(v_ente ge_pag_recaudaciones.cod_ente%TYPE,
     v_cod_moneda ge_pag_recaudaciones.cod_moneda%TYPE
     ) is
    select a.*
       from ge_mov_pen_cobranzas a
      where a.fec_cobro = v_fec_actual
        and a.estado = 'P'
        --and a.concepto like '%Cobranza de Seguros.%'
        and nvl(a.cierre,'N')='S'
        and (to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))))= p_cod_ente
        and a.cod_moneda= v_cod_moneda;
  CURSOR g_datos is
    SELECT A.* FROM GE_ENV_PAG_RECAUDACIONES_TMP A
        ORDER BY A.CTA_CREDITO;

begin
   select upper(sys_context('USERENV', 'DB_NAME'))
    into v_db_name
    from dual;
    -- Envio de mail al titular de cta credito.
    for j in g_ente loop
      delete from ge_env_pag_recaudaciones_tmp;
      --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
       v_texto := '<br><br>
                   <br><br>
                     Estimado Cliente:
                   <br><br>
                     Le informamos que se realizó el proceso de servicios de recaudaciones y cobranzas correspondiente a la fecha ' ||
                             to_char(v_fec_actual, 'DD/MM/YYYY') || ',' || ' en el cual se realizaron las operaciones detalladas en el archivo adjunto.
                   <br><br>
                     Atentamente.
                   <br><br>
                   <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                   <br><br>
                   <br><br>';


         v_cabecera := 'Cliente' || chr(9) || 'Fecha' || chr(9) || 'Nro. Archivo' ||
                    chr(9) || 'Cuenta de débito' || chr(9) ||
                    'Cuenta de crédito' || chr(9) || 'Monto' || chr(9) ||
                    'Moneda' || chr(9) || 'Número de Documento' || chr(9)||'Concepto'||chr(10);

      v_texto_detalle   := null;
      v_texto_detalle2  := null;
      v_adjunto         := null;
      v_adjunto_error   := null;
      v_total_procesado := 0;
      v_tot_procesado   := null;
      v_tot_error       := null;
      v_det_error       := null;
      v_hini_mail       := to_char(sysdate,'hh24:mi:ss');
      v_can_normal      :=0;
      v_can_error       :=0;
      BEGIN
        for k in c_rec(j.cod_ente,j.cod_moneda) loop
          v_insertar:='N';
          --Buscamos los datos de las recaudaciones
          v_nro_registro:= null;
          v_cod_ent_mov_pen := null;
          v_nro_cta_credito:= null;
          v_nro_cta_debito:= null;
          v_nro_archivo:= null;
          v_nro_factura:= null;
          v_tip_cobranza:= null;
          v_nom_ente        := null;
          v_cod_per_credito := null;
          v_dir_mail_cre    := null;
          v_nom_cli_debito := null;
          v_nro_factura:= null;
          v_concepto  :=null;

          --v_nro_registro:= trim(substr(k.observacion, 1, instr(k.observacion,'-') -1));
          v_nro_cta_debito  :=  k.nro_cuenta;
          v_cod_ent_mov_pen := j.cod_ente;--to_number(trim(substr(k.concepto, 1, instr(k.concepto,'-') -1)));
          v_nom_ente        := fue_obt_nom_ente(v_cod_ent_mov_pen);
          v_cod_per_credito := fug_obt_cli_principal(v_nro_cta_credito);
          v_dir_mail_cre    := fug_obt_parentes(v_cod_ent_mov_pen,'DIR_MAIL_SR');
          v_nro_factura := trim(substr(k.observacion,instr(k.observacion,'Corresponde'),150)) ;
          --
           if j.cod_moneda= pag_gen.fu_obt_mon_local then
              v_nro_cta_credito := fug_obt_parentes(j.cod_ente, 'NRO_CTA_RECAUDADORA_GS');
           elsif j.cod_moneda= pag_gen.fu_obt_mon_fuerte  then
              v_nro_cta_credito := fug_obt_parentes(j.cod_ente, 'NRO_CTA_RECAUDADORA_USD');
           else
              v_nro_cta_credito := fug_obt_parentes(j.cod_ente, 'NRO_CTA_RECAUDADORA_EUR');
           end if;
           v_cod_per_debito := fug_obt_cli_principal(v_nro_cta_debito);
           v_nom_cli_debito  := fue_obt_nom_persona(v_cod_per_debito);
           v_total_procesado := v_total_procesado + nvl(k.monto, 0);
           v_concepto:= nvl(fue_obt_des_refcodes('TIP_COB_RECAUDACION', 4),'COBRANZA RECAUDACION');
           insert into ge_env_pag_recaudaciones_tmp(COD_ENTE,CLIENTE,
             FEC_OPERACION,NRO_ARCHIVO,CTA_DEBITO,CTA_CREDITO,MONTO,COD_MONEDA,CONCEPTO,
             OBSERVACION,TIPO,nro_factura,tip_cobranza)
           values(v_cod_ent_mov_pen,v_nom_cli_debito,
                 to_char(k.fecha, 'DD/MM/YYYY'),1,v_nro_cta_debito,
                 v_nro_cta_credito, k.monto, k.cod_moneda,v_nro_factura,
                 v_concepto,'N',
                 v_nro_factura,4);

        end loop;

              v_tot_procesado:= v_total_procesado;
              v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                               v_cabecera || chr(10);-- || v_adjunto || chr(10)||
              v_pie_normal:= chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||v_tot_procesado||chr(10);



     EXCEPTION
        when others then
           v_det_error := substr(sqlerrm,1,4000);
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, 'pag_rec_cie.txt','ERROR', 'Proc.Recaud.Envio.Mail', v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
     END;
      --

      if v_dir_mail_cre is not null and fug_ind_produccion = 'S' then
       --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante|
        v_nom_adj := 'BBVA_SRC_' || j.cod_ente || '_' ||
                     to_char(v_fec_actual, 'DDMMYY')|| '_' ||j.cod_moneda;
        v_asunto   := 'Recaudaciones y Cobranzas';
        v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                      chr(10) || chr(10) || chr(10) || V_FIN|| chr(10) || V_PIE;
        v_det_error    := null;
        BEGIN
                    v_tip_cobranza:='N';
                    v_conn     := it_mail.begin_mail(c_dir_mail,
                                                     v_dir_mail_cre,
                                                     v_asunto,
                                                     IT_MAIL.MULTIPART_MIME_TYPE);

                    it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

                    it_mail.begin_attachment(v_conn,
                                             'text/plain',
                                             false,
                                             v_nom_adj || '.xls');

                     v_texto_detalle := chr(10) || CHR(9) || CHR(9) ||
                                       'SERVICIO DE RECAUDACIONES Y COBRANZAS' || CHR(10)||
                                       v_texto_detalle;

                    it_mail.write_text(v_conn, v_texto_detalle);
                    --************Para Grabar Detalle **************************************
                        for w in g_datos loop
                           v_adjunto:=null;
                             v_adjunto :=  W.CLIENTE || '.' || chr(9) ||
                                 W.fec_operacion || chr(9) ||
                                 to_char(W.nro_archivo) || chr(9) ||
                                 W.CTA_DEBITO || chr(9) || W.cta_credito ||
                                 chr(9) || W.monto || chr(9) || W.cod_moneda || '.' ||
                                 chr(9) || W.nro_factura || '.' ||chr(9)||w.observacion|| chr(10);


                            it_mail.write_text(v_conn, v_adjunto);
                         end loop;
                         --************fin de Grabar Detalle **************************************

                     it_mail.write_text(v_conn, v_pie_normal);
                     if nvl(v_can_error,0)=0 then
                         it_mail.end_mail(v_conn);
                     end if;

       EXCEPTION
        when utl_smtp.transient_error or utl_smtp.permanent_error then
            begin
              utl_smtp.quit(v_conn);
            exception
            when utl_smtp.transient_error or utl_smtp.permanent_error then
              v_det_error := substr(sqlerrm,1,4000);
            end;
            v_det_error := substr(sqlerrm,1,4000);
       END;

        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_nom_adj, c_dir_mail, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
            v_det_error    := null;
        END IF;
     end if;

  end loop;

EXCEPTION
    when others then
    v_det_error:=sqlerrm;
    INSERT INTO ge_ra_log_mail
     (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, 'Proc.Env.Mail', c_dir_mail, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
     COMMIT;
end;



-- FMM 25/03/2014 Procedimiento para enviar mail de Servicio de Recaudaciones al titular de credito

PROCEDURE PR_SRC_ATTACH_XLS(p_cod_ente IN ge_entes.cod_ente%TYPE DEFAULT NULL) IS

  v_fec_actual date default pag_cal.fu_obt_fec_actual(1);

  v_cod_per_debito  ge_cta_clientes.cod_persona%type;
  v_cod_per_credito ge_cta_clientes.cod_persona%type;
  v_nom_ente        ge_entes.descripcion%type;
  v_dir_mail_deb    varchar2(300);--ba_personas.dir_correo%type;
  v_dir_mail_cre    varchar2(300);--ba_personas.dir_correo%type;
  v_nom_cli_debito  ba_personas.nom_completo%type;

  v_texto         varchar2(1000);
  v_texto_detalle clob;
  v_texto_detalle2 clob;
  v_adjunto       clob;
  v_adjunto_error clob;
  v_cabecera      clob;
  v_nom_adj varchar2(500);
  v_total_procesado number ;
  v_total_error number ;

  v_tot_procesado varchar2(100);
  v_tot_error varchar2(100);

  -- Variables para mail
  v_conn     utl_smtp.connection;
  v_asunto   VARCHAR2(2000);
  v_mje_mail LONG;
  v_db_name  VARCHAR2(20);
  --
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;
  --
  v_can_normal      number(10):=0;
  v_can_error       number(10):=0;
  v_pie_normal      varchar2(30000);
  v_pie_error       varchar2(30000);
  v_tip_cobranza   varchar2(1);

  --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  v_membrete LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P',c_dir_mail);
  --

  CURSOR g_ente is
    select distinct cod_ente,a.cod_moneda,a.nro_archivo
      from ge_pag_recaudaciones a
     where a.fec_operacion = v_fec_actual
       and a.usu_modificacion = USER
       and a.estado in ('E', 'N')
       and (p_cod_ente IS NULL OR a.cod_ente = p_cod_ente)
     order by cod_ente,a.cod_moneda,a.nro_archivo;

  CURSOR c_rec(v_ente ge_pag_recaudaciones.cod_ente%TYPE,
     v_cod_moneda ge_pag_recaudaciones.cod_moneda%TYPE,
     v_nro_archivo ge_pag_recaudaciones.nro_archivo%TYPE
   ) is
    /*select * \* distinct(a.cod_ente)*\
      from ge_pag_recaudaciones a
     where a.fec_operacion = v_fec_actual
       and a.estado in ('E', 'N')
       and a.cod_ente = v_ente
       and a.cod_moneda= v_cod_moneda
       and a.nro_archivo=v_nro_archivo
       and a.usu_modificacion = USER
     order by a.cod_ente,a.cod_moneda,a.nro_archivo;*/
     Select A.COD_ENTE,
            FUE_OBT_NOM_ENTE(A.COD_ENTE) DESCRIPCION,
            A.FEC_OPERACION,
            A.NRO_ARCHIVO,
            A.NRO_CTA_DEBITO,
            FUG_OBT_NOM_CUENTA(A.NRO_CTA_DEBITO) NOM_CTA_DEBITO,
            A.NRO_CTA_CREDITO,
            A.COD_MONEDA,
            A.MONTO,
            A.estado,
            FUE_OBT_DES_REFCODES('EST_SER_RECAUDACIONES', A.ESTADO) DES_ESTADO,
            A.NRO_FACTURA,
            decode(a.tip_cobranza,1,'FACTURAS',2,'CUOTA',3,'APORTE',4,'SEGURO') TIP_COBRANZA,
            NULL MSJ_ERROR,
            a.fec_cobro,
            'N' Mov_Pendiente
       From GE_PAG_RECAUDACIONES A
      WHERE a.estado != 'E'
        AND a.fec_operacion = v_fec_actual
        and a.cod_ente = v_ente
        and a.cod_moneda= v_cod_moneda
        and a.nro_archivo= v_nro_archivo
      Union All
     Select B.COD_ENTE,
            FUE_OBT_NOM_ENTE(B.COD_ENTE) DESCRIPCION,
            B.FEC_OPERACION,
            B.NRO_ARCHIVO,
            B.NRO_CTA_DEBITO,
            FUG_OBT_NOM_CUENTA(B.NRO_CTA_DEBITO) NOM_CTA_DEBITO,
            B.NRO_CTA_CREDITO,
            B.COD_MONEDA,
            B.MONTO,
            null estado,
            'CANCELADO POR ERRORES',
            B.NRO_FACTURA,
            decode(b.tip_cobranza,1,'FACTURAS',2,'CUOTA',3,'APORTE',4,'SEGURO','COBRANZA') TIP_COBRANZA,
           /* case
              when nvl(b.tip_cobranza,0) <> 4 and  b.msj_error like '%Saldo Insuficiente p/ el debito%' then
                null
              else
                trim(TO_CHAR(B.COD_ERROR)||' - ' || B.MSJ_ERROR)
            end MSJ_ERROR,*/
            trim(TO_CHAR(B.COD_ERROR)||' - ' || B.MSJ_ERROR) MSJ_ERROR,
            null Fec_cobro,
            NVL((select 'S'
                   from ge_mov_pen_cobranzas w --ge_mov_pendientes W --04/07/2016 se utiliza nueva tabla
                   where W.fecha <= b.fec_operacion
                     and W.cod_moneda= nvl(b.cod_moneda,w.cod_moneda)
                     --and w.concepto like '%Cobranza de Seguros.%'
                     and trim(substr(W.concepto, 1, instr(W.concepto,'-') -1)) = trim(to_char(b.cod_ente))
                     and b.nro_cta_debito = w.nro_cuenta
                     and b.cod_error in (25, 29, 31, 36)
                     and w.estado <> 'X'
                     and rownum = 1),'N') Mov_Pendiente
       From GE_PAG_RECAUDACIONES_ERR B
      Where b.fec_operacion = v_fec_actual
        and b.cod_ente = v_ente
        and b.cod_moneda = v_cod_moneda
        and b.nro_archivo = v_nro_archivo;

  CURSOR g_datos is
    SELECT A.* FROM GE_ENV_PAG_RECAUDACIONES_TMP A
     where a.tipo=v_tip_cobranza
        ORDER BY A.CTA_CREDITO;

begin
  select upper(sys_context('USERENV', 'DB_NAME'))
    into v_db_name
    from dual;
  begin
    -- Envio de mail al titular de cta credito.
    for j in g_ente loop
       delete from ge_env_pag_recaudaciones_tmp;
      --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
       v_texto := '<br><br>
                   <br><br>
                     Estimado Cliente:
                   <br><br>
                     Le informamos que se realizó el proceso de servicios de recaudaciones y cobranzas correspondiente a la fecha ' ||
                             to_char(v_fec_actual, 'DD/MM/YYYY') || ',' || ' en el cual se realizaron las operaciones detalladas en el archivo adjunto.
                   <br><br>
                     Atentamente.
                   <br><br>
                   <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                   <br><br>
                   <br><br>';


      v_cabecera := 'Ente' || chr(9) || 'Descripcion' || chr(9) || 'Fec Operacion' || chr(9) ||
                    'Nro Archivo' || chr(9) || 'Cuenta Debito' || chr(9) || 'Denominacion' || chr(9) ||
                    'Cuenta de crédito' || chr(9) || 'Moneda' || chr(9) || 'Monto' || chr(9) ||
                    'Estado' || chr(9) || 'Referencia' || chr(9) || 'Tip Cobranza' || chr(9)||
                    'Msj Error' || chr(9)|| 'Mov Pendiente' ||chr(10);

      v_texto_detalle := null;
      v_texto_detalle2:= null;

      v_adjunto       := null;
      v_adjunto_error := null;
      v_total_procesado := 0;
      v_total_error := 0;
      v_tot_procesado:= null;
      v_tot_error:= null;
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');
      v_can_normal:=0;
      v_can_error:=0;
      BEGIN
        for k in c_rec(j.cod_ente,j.cod_moneda,j.nro_archivo) loop

          v_nom_ente        := fue_obt_nom_ente(k.cod_ente);
          v_cod_per_debito  := fug_obt_cli_principal(k.nro_cta_debito);
          v_cod_per_credito := fug_obt_cli_principal(k.nro_cta_credito);
          v_dir_mail_deb    := fug_obt_dir_mail_per(v_cod_per_debito);
          v_dir_mail_cre    := fug_obt_parentes(j.cod_ente,'DIR_MAIL_SR');
          v_nom_cli_debito  := fue_obt_nom_persona(v_cod_per_debito);

          if k.estado = 'N' THEN
           v_total_procesado := v_total_procesado + nvl(k.monto, 0);
            insert into ge_env_pag_recaudaciones_tmp(COD_ENTE,CLIENTE,
               FEC_OPERACION,NRO_ARCHIVO,CTA_DEBITO,CTA_CREDITO,MONTO,COD_MONEDA,CONCEPTO,
               OBSERVACION,TIPO,nro_factura,tip_cobranza)
             values(j.cod_ente,v_nom_cli_debito, to_char(k.fec_operacion, 'DD/MM/YYYY'),
                    k.nro_archivo,k.nro_cta_debito, k.nro_cta_credito, k.monto,
                    k.cod_moneda,k.mov_pendiente, k.msj_error,'N', k.nro_factura/*to_number(k.nro_factura)*/,k.tip_cobranza);
           /* v_adjunto := v_adjunto || v_nom_cli_debito || '.' || chr(9) ||
                         to_char(k.fec_operacion, 'DD/MM/YYYY') || chr(9) ||
                         to_char(k.nro_archivo) || chr(9) ||
                         k.nro_cta_debito || chr(9) || k.nro_cta_credito ||
                         chr(9) || k.monto || chr(9) || k.cod_moneda || '.' ||
                         chr(9) || k.nro_factura || '.' ||chr(9)||fue_obt_des_refcodes('TIP_COB_RECAUDACION', k.tip_cobranza)|| chr(10);
*/
          else
            v_total_error := v_total_error + nvl(k.monto, 0);
            insert into ge_env_pag_recaudaciones_tmp(COD_ENTE,CLIENTE,
               FEC_OPERACION,NRO_ARCHIVO,CTA_DEBITO,CTA_CREDITO,MONTO,COD_MONEDA,CONCEPTO,
               OBSERVACION,TIPO,nro_factura,tip_cobranza)
             values(j.cod_ente,v_nom_cli_debito,to_char(k.fec_operacion, 'DD/MM/YYYY'),
                    k.nro_archivo,k.nro_cta_debito,k.nro_cta_credito, k.monto,
                    k.cod_moneda,k.mov_pendiente,k.msj_error,'E',k.nro_factura/*to_number(k.nro_factura)*/,k.tip_cobranza);
           /* v_adjunto_error := v_adjunto_error || v_nom_cli_debito || '.' ||
                               chr(9) ||
                               to_char(k.fec_operacion, 'DD/MM/YYYY') ||
                               chr(9) ||
                               to_char(k.nro_archivo) ||
                               chr(9) || k.nro_cta_debito || chr(9) ||
                               k.nro_cta_credito || chr(9) || k.monto  ||
                               chr(9) || k.cod_moneda || '.' || chr(9) ||
                               k.nro_factura || '.' ||chr(9)||fue_obt_des_refcodes('TIP_COB_RECAUDACION', k.tip_cobranza)|| chr(10);*/
          end if;
        end loop;
      --Verificamos si se insertaron registros normales en la tabla para enviar.
      begin
        select count(*)
          into v_can_normal
          from ge_env_pag_recaudaciones_tmp a
             where a.cod_ente=j.cod_ente
             and a.cod_moneda=j.cod_moneda
             and a.nro_archivo=j.nro_archivo
             and a.tipo='N';
      exception
        when no_data_found then
          v_can_normal:=0;
        when others then
           v_can_normal:=0;
      end;
        --Verificamos si se insertaron registros con errores en la tabla para enviar.
      begin
        select count(*)
          into v_can_error
          from ge_env_pag_recaudaciones_tmp a
             where a.cod_ente=j.cod_ente
             and a.cod_moneda=j.cod_moneda
             and a.nro_archivo=j.nro_archivo
             and a.tipo='E';
      exception
        when no_data_found then
          v_can_error:=0;
        when others then
           v_can_error:=0;
      end;

         if nvl(v_can_normal,0)> 0 then
            v_tot_procesado:= v_total_procesado;
            v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                               v_cabecera || chr(10);-- || v_adjunto || chr(10)||
            v_pie_normal:= chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||v_tot_procesado||chr(10);
          end if;

         if  nvl(v_can_error,0)> 0 then
            v_tot_error:= v_total_error;
            v_texto_detalle2 :='Operaciones no Procesadas' ||
                               chr(10) ||'Motivo: No se pudo realizar el débito a la cuenta '||chr(10)||v_cabecera || chr(10); --||
                               --v_adjunto_error|| chr(10)||
             v_pie_error:= chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||'Total No Procesados :'||chr(9)||v_tot_error||chr(10);
         end if;
      EXCEPTION
        when others then
           v_det_error := substr(sqlerrm,1,4000);
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, 'pag_rec_mai.txt','ERROR', 'Proc.Recaud.Envio.Mail', v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;

      END;

      if v_dir_mail_cre is not null and fug_ind_produccion = 'S' then

        --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante|
        v_nom_adj := 'BBVA_SRC_' || j.cod_ente || '_' ||
                     to_char(v_fec_actual, 'DDMMYY')|| '_' ||j.cod_moneda;

        v_asunto   := 'Recaudaciones y Cobranzas';
        v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                      chr(10) || chr(10) || chr(10) || V_FIN|| chr(10) || V_PIE;

        v_det_error    := null;
        BEGIN

            if nvl(v_can_normal,0)>0 then
               --******************PARA NORMAL *************************************
                    v_tip_cobranza:='N';
                    v_conn     := it_mail.begin_mail(c_dir_mail,
                                                     v_dir_mail_cre,
                                                     v_asunto,
                                                     IT_MAIL.MULTIPART_MIME_TYPE);

                    it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

                    it_mail.begin_attachment(v_conn,
                                             'text/plain',
                                             false,
                                             v_nom_adj || '.xls');

                     v_texto_detalle := chr(10) || CHR(9) || CHR(9) ||
                                       'SERVICIO DE RECAUDACIONES Y COBRANZAS' || CHR(10)||
                                       v_texto_detalle;

                    it_mail.write_text(v_conn, v_texto_detalle);
                    --************Para Grabar Detalle **************************************
                        for w in g_datos loop
                           v_adjunto:=null;
                             v_adjunto :=  w.cod_ente || chr(9) || fue_obt_nom_ente(w.cod_ente) || chr(9) ||
                                 W.fec_operacion || chr(9) || to_char(W.nro_archivo) || chr(9) ||
                                 W.CTA_DEBITO || chr(9) || W.CLIENTE || chr(9) || W.cta_credito || chr(9) ||
                                 W.cod_moneda || chr(9) || W.monto || chr(9) || 'Procesado' || chr(9) ||
                                 w.nro_factura || chr(9) || w.tip_cobranza || chr(9) || w.observacion || chr(9) ||
                                 w.concepto || chr(10);

                            it_mail.write_text(v_conn, v_adjunto);
                         end loop;
                         --************fin de Grabar Detalle **************************************

                     it_mail.write_text(v_conn, v_pie_normal);
                     if nvl(v_can_error,0)=0 then
                         it_mail.end_mail(v_conn);
                     end if;
            end if;
            if nvl(v_can_error,0)>0 then
                --*****************Para Errores************************************************
                    v_tip_cobranza:='E';
                    if nvl(v_can_normal,0)=0 then
                        v_conn     := it_mail.begin_mail(c_dir_mail,
                                                         v_dir_mail_cre,
                                                         v_asunto,
                                                         IT_MAIL.MULTIPART_MIME_TYPE);

                        it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

                        it_mail.begin_attachment(v_conn,
                                                 'text/plain',
                                                 false,
                                                 v_nom_adj || '.xls');
                     end if;
                     v_texto_detalle2 := chr(10) || CHR(9) || CHR(9) ||
                                       'SERVICIO DE RECAUDACIONES Y COBRANZAS' || CHR(10)||
                                      v_texto_detalle2;

                    it_mail.write_text(v_conn, v_texto_detalle2);
                    --************Para Grabar Detalle **************************************
                        for w in g_datos loop
                           v_adjunto:=null;
                             v_adjunto :=  w.cod_ente || chr(9) || fue_obt_nom_ente(w.cod_ente) || chr(9) ||
                                 W.fec_operacion || chr(9) || to_char(W.nro_archivo) || chr(9) ||
                                 W.CTA_DEBITO || chr(9) || W.CLIENTE || chr(9) || W.cta_credito || chr(9) ||
                                 W.cod_moneda || chr(9) || W.monto || chr(9) || 'Cancelado' || chr(9) ||
                                 w.nro_factura || chr(9) || w.tip_cobranza || chr(9) ||
                                 w.observacion || chr(9) || w.concepto || chr(10);

                            it_mail.write_text(v_conn, v_adjunto);
                         end loop;
                         --************fin de Grabar Detalle **************************************

                     it_mail.write_text(v_conn, v_pie_error);
                     it_mail.end_mail(v_conn);
           end if;
       EXCEPTION
        when utl_smtp.transient_error or utl_smtp.permanent_error then
            begin
              utl_smtp.quit(v_conn);
            exception
            when utl_smtp.transient_error or utl_smtp.permanent_error then
              null;
            end;
            v_det_error := substr(sqlerrm,1,4000);
       END;

        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_nom_adj, c_dir_mail, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
            v_det_error    := null;
        END IF;
      end if;

    end loop;

  EXCEPTION
    when others then
      null;
  END;
end;

----------------------------------------------------------------------------------

   -- OMM Cobro de Cargos por Ente
PROCEDURE PR_COB_CARGOS
   IS
   --v_hora             ge_movimientos.hora%type := pag_gen.fu_obt_sig_segundo(to_char(sysdate,'hh24:mi:ss')); --DYDMR-9821
   v_nro_secuencia    ge_movimientos.nro_secuencia%type := -999;
   v_fec_actual       ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(1);
   v_cod_tra_cargo    ge_transacciones.cod_transaccion%type := null;
   v_cod_tas_car_tot  ge_tas_fechas.cod_tasa%type;
   v_cod_tas_car_liq  ge_tas_fechas.cod_tasa%type;
   v_cod_tas_lote     ge_tas_fechas.cod_tasa%type;
   v_mon_total        ge_pag_recaudaciones.monto%type := 0 ;
   v_cod_ente         ge_entes.cod_ente%type;
   v_cod_moneda       ge_cuentas.cod_moneda%type;
   v_cantidad         number(6) := 0 ;
   v_ser_costo        varchar2(10);
   v_fec_ini_contrato date;
   v_fec_fin_contrato date;
   v_cod_modulo       ge_transacciones.cod_modulo%type;
   v_cod_modalidad    ge_transacciones.cod_modalidad%type;
   v_cod_mod_padre    ge_transacciones.cod_modulo%type;
   v_cod_mad_padre    ge_transacciones.cod_modalidad%type;
   v_cod_ofi_origen   ge_cuentas.cod_oficina%type;
   v_cta_rec_gs       ge_cuentas.nro_cuenta%type;
   v_cta_rec_usd      ge_cuentas.nro_cuenta%type;
   v_cta_rec_eur      ge_cuentas.nro_cuenta%type;
   v_cta_cargo        ge_cuentas.nro_cuenta%type;
   v_nvo_estado       ge_cuentas.estado%type;
   v_sal_disponible   cc_cta_corrientes.sal_total%type;
   v_cod_tra_padre    ge_transacciones.cod_transaccion%type;
   v_ser_activo       varchar2(1);
   v_can_dia_pago     varchar2(10);

   v_cod_tas_costo    ge_tas_fechas.cod_tasa%type;
   v_val_tasa         ge_tas_fechas.val_tasa%type;
   v_val_cargo        ge_tas_fechas.val_tasa%type;
   v_cod_tra_impuesto ge_transacciones.cod_transaccion%type;
   v_cod_tas_impuesto ge_transacciones.cod_tasa%type;
   v_val_tas_impuesto ge_tas_fechas.val_tasa%type;
   v_val_impuesto     ge_tas_fechas.val_tasa%type;
   v_procesado        varchar2(1) := 'S' ;
   ---
   v_val_exo_cargo    ge_movimientos.val_tasa%type;
   v_val_exo_impuesto ge_movimientos.val_tasa%type;
   v_tip_valor        ge_tasas.tip_valor%type;
   v_redondeo         NUMBER;
   --DYDMR-9821 - Incidencia SAU - ITGF-Error Cierre 31/10/2018
   v_hora             ge_movimientos.hora%type := fug_obt_hor_disponible(v_fec_actual,to_char(sysdate,'hh24:mi:ss'), USER, 'N');
   CURSOR c_entes is
   --DYDMR-8028-Incidencia SAU - ITGF - no cobro de comisiones
   Select distinct cod_ente, cod_moneda
     from (select distinct (a.cod_ente) cod_ente, a.cod_moneda
             from ge_pag_recaudaciones a
            where a.fec_operacion = v_fec_actual
              and a.estado in ('E', 'N')
           union all
           select distinct (to_number(trim(substr(e.concepto, 1, instr(e.concepto,'-') -1)))) cod_ente, e.cod_moneda
             from ge_mov_pen_cobranzas e
            where e.fec_cobro = v_fec_actual
              and e.estado = 'P');

-- Generar movimientos pendientes
procedure lp_gen_mov_pendiente is
   begin
      insert into ge_mov_pendientes
            (nro_cuenta, fecha, cod_modulo, cod_modalidad,
             cod_transaccion, cod_mod_padre, cod_mad_padre, cod_tra_padre,
             monto, hora, cod_usuario, cod_moneda, cod_oficina, cod_error,
             estado, cod_ofi_origen, concepto, cod_tasa,
             val_tasa, nro_documento, saldo, motivo)
      values
            (v_cta_cargo, v_fec_actual, v_cod_modulo, v_cod_modalidad,
             v_cod_tra_cargo, v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre,
             (v_val_cargo + v_val_impuesto), v_hora, user, v_cod_moneda, v_cod_ofi_origen, pag_cta.g_cod_error,
            'I', v_cod_ofi_origen, substr('Déb.por Cargo de Serv.Rec.'||v_cantidad,1,35), v_cod_tas_costo,
            v_val_tasa, v_cod_ente, v_sal_disponible, pag_cta.G_MSJ_ERROR);
exception
  when others then
    raise_application_error(-20000,'Error al tratar de procesar mov_pendeinte '||v_cta_cargo||'-'||sqlerrm);
end;

   Begin
      for e in c_entes loop

         PR_OBT_DAT_SERVICIOS(e.cod_ente,
                              null,         -- En el cobro de cargos no existe cuenta debito cliente
                              9999999999,   -- Se pasa un nro unico por el proceso de cobro de cargos
                              v_fec_actual,
                              v_ser_costo,
                              v_fec_ini_contrato,
                              v_fec_fin_contrato,
                              v_cta_rec_gs,
                              v_cta_rec_usd,
                              v_cta_rec_eur,
                              v_cod_tra_padre,
                              v_ser_activo,
                              v_can_dia_pago);

     v_cod_tra_cargo   := fug_obt_parentes(e.cod_ente,'COD_TRA_CAR_SR');
     v_cod_tas_car_liq := fug_obt_parentes(e.cod_ente,'COD_TAS_CAR_LIQUIDA');
     v_cod_tas_car_tot := fug_obt_parentes(e.cod_ente,'COD_TAS_CAR_ORDEN');
     v_cod_tas_lote    := fug_obt_parentes(e.cod_ente,'COD_TAS_COSTO');
     v_cod_ente        := e.cod_ente ;
     v_cod_moneda      := e.cod_moneda ;

     if v_cod_tas_lote is not null then
        select count(distinct(a.nro_archivo)) Cantidad
              into v_cantidad
              from ge_pag_recaudaciones a
             where a.fec_operacion = v_fec_actual
               and a.cod_ente   = e.cod_ente
               and a.cod_moneda = e.cod_moneda ;

              v_cod_tas_costo := v_cod_tas_lote ;

     elsif v_cod_tas_car_liq is not null then
           --DYDMR-8028 - Incidencia SAU - ITGF - no cobro de comisiones
           Select sum(monto) monto, count(Cantidad)
             into v_mon_total, v_cantidad
             from (select nvl(sum(a.monto), 0) monto, count(*) Cantidad
                     from ge_pag_recaudaciones a
                    where a.fec_operacion = v_fec_actual
                      and a.estado = 'N'
                      and a.cod_ente = e.cod_ente
                      and a.cod_moneda = e.cod_moneda
                   union all
                   select nvl(sum(p.monto), 0) monto, count(*) Cantidad
                     from ge_mov_pen_cobranzas p
                    where p.fec_cobro = v_fec_actual
                      and p.estado = 'P'
                      and to_number(trim(substr(p.concepto, 1, instr(p.concepto,'-') -1))) = e.cod_ente                      
                      and p.cod_moneda = e.cod_moneda);

              v_cod_tas_costo := v_cod_tas_car_liq ;

     elsif v_cod_tas_car_tot is not null then
             select nvl(sum(a.monto),0) monto, count(*) Cantidad
               into v_mon_total, v_cantidad
               from ge_pag_recaudaciones a
              where a.fec_operacion = v_fec_actual
                and a.estado in ('N','E')
                and a.cod_ente   = e.cod_ente
                and a.cod_moneda = e.cod_moneda ;

              v_cod_tas_costo := v_cod_tas_car_tot ;
     end if ;

           if e.cod_moneda = 'GS' then
              v_cta_cargo := v_cta_rec_gs ;
           elsif e.cod_moneda = 'USD' then
              v_cta_cargo := v_cta_rec_usd ;
           elsif  e.cod_moneda = 'EUR' then
              v_cta_cargo := v_cta_rec_eur ;
           end if ;

           pag_cta.PR_OBT_CUENTA(v_cta_cargo) ;

           if nvl(v_cantidad,0) > 0 and v_cod_tas_costo is not null and nvl(v_ser_activo,'N') = 'S' then
              PAG_REC.PR_OBT_CARGOS(pag_cta.G_CTAS.cod_oficina, v_cta_cargo, e.cod_moneda, v_cantidad,
                                    v_mon_total, pag_cta.G_CTAS.cod_modulo, pag_cta.G_CTAS.cod_modalidad,
                                    v_cod_tra_cargo,'S', v_cod_tas_costo, v_val_tasa, v_val_cargo,
                                    v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto);

              v_cod_mod_padre  := pag_cta.G_CTAS.cod_modulo ;
              v_cod_mad_padre  := pag_cta.G_CTAS.cod_modalidad ;
              v_cod_ofi_origen := pag_cta.G_CTAS.cod_oficina ;

              /*
              || PCC-Exoneracion y Extorno de Comisiones y Tasas
              || Se ejecuta si el proceso no es mensual
              || o la base de datos no es produccion
              */
              IF g_fre_proceso <> 'M' OR g_db_prod = 'N' THEN
                 -- busco el valor de la tasa
                 begin
                    v_val_exo_cargo := fug_obt_val_tasa(pag_cta.G_CTAS.cod_modulo,
                                                        pag_cta.G_CTAS.cod_modalidad,
                                                        pag_cta.G_CTAS.cod_oficina,
                                                        null,
                                                        pag_cta.G_CTAS.cod_moneda,
                                                        0, 'N', v_cod_tas_costo, -- DYDMR-10349 IEC 07
                                                        v_cod_tra_cargo,
                                                        v_fec_actual);
                 exception
                    when others then
                       raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                 end;
                 v_tip_valor := fug_obt_tip_val_tasa(v_cod_tas_costo);
                 v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                   pag_cta.G_CTAS.cod_modulo,
                                                   pag_cta.G_CTAS.cod_modalidad,
                                                   pag_cta.G_CTAS.cod_moneda);
                 IF v_tip_valor = 'V' THEN
                    -- si es un valor, se toma directamente
                    v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
                 ELSE
                    -- es un porcentaje
                    v_val_exo_cargo := round(nvl(v_mon_total, 0) * nvl(v_val_exo_cargo, 0) / 100, v_redondeo);
                    --verificar si el monto a cobrar esta limitado x el minimo y maximo de la tasa
                    v_val_exo_cargo := pag_gen.fu_obt_val_final(v_val_exo_cargo);
                 END IF;                 
                 -- DYDMR-10349 IEC 07 - se modifica lugar de calculo de impuesto para igualar montos a comparar 
                 begin
                    v_val_exo_impuesto := fug_obt_val_tasa(pag_cta.G_CTAS.cod_modulo,
                                                           pag_cta.G_CTAS.cod_modalidad,
                                                           pag_cta.G_CTAS.cod_oficina,
                                                           null,
                                                           pag_cta.G_CTAS.cod_moneda,
                                                           0, 'N', NULL,
                                                           v_cod_tra_impuesto,
                                                           v_fec_actual);
                 exception
                    when others then
                       raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                 end;
                 
                 v_val_exo_impuesto := round(nvl(v_val_exo_cargo, 0) * nvl(v_val_exo_impuesto, 0) /
                                        (100 + v_val_exo_impuesto), v_redondeo);
                 -- Se resta el impuesto             
                 v_val_exo_cargo    := round(v_val_exo_cargo - v_val_exo_impuesto, v_redondeo);
                 
                 if pag_cta.fu_ver_tra_prohibida(v_cta_cargo,
                                                 v_cod_tra_cargo,
                                                 pag_cta.G_CTAS.cod_modulo,
                                                 pag_cta.G_CTAS.cod_modalidad) = 'S' then
                    prg_ins_exoneracion(v_cod_tra_cargo, pag_cta.G_CTAS.cod_modulo,
                                        pag_cta.G_CTAS.cod_modalidad, pag_cta.G_CTAS.cod_moneda,
                                        v_cta_cargo, null, v_cod_tas_costo,
                                        nvl(v_val_exo_cargo, 0),
                                        nvl(v_val_exo_cargo, 0), null,
                                        nvl(v_val_exo_cargo, 0));
                 elsif (nvl(v_val_cargo, 0) <> nvl(v_val_exo_cargo, 0)) or
                       (nvl(v_val_cargo, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0) then
                    prg_ins_exoneracion(v_cod_tra_cargo, pag_cta.G_CTAS.cod_modulo,
                                        pag_cta.G_CTAS.cod_modalidad, pag_cta.G_CTAS.cod_moneda,
                                        v_cta_cargo, null, v_cod_tas_costo,
                                        (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)),
                                         v_val_exo_cargo, null,
                                        (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)));
                 end if;
                 
                 if pag_cta.fu_ver_tra_prohibida(v_cta_cargo,
                                                 v_cod_tra_impuesto,
                                                 pag_cta.G_CTAS.cod_modulo,
                                                 pag_cta.G_CTAS.cod_modalidad) = 'S' then
                    prg_ins_exoneracion(v_cod_tra_impuesto, pag_cta.G_CTAS.cod_modulo,
                                        pag_cta.G_CTAS.cod_modalidad, pag_cta.G_CTAS.cod_moneda,
                                        v_cta_cargo, null, v_cod_tas_impuesto,
                                        nvl(v_val_exo_impuesto, 0),
                                        nvl(v_val_exo_impuesto, 0), null,
                                        nvl(v_val_exo_impuesto, 0));
                 elsif pag_cta.fu_ver_tra_prohibida(v_cta_cargo,
                                                    v_cod_tra_cargo,
                                                    pag_cta.G_CTAS.cod_modulo,
                                                    pag_cta.G_CTAS.cod_modalidad) = 'S' then
                       null;
                 elsif (nvl(v_val_impuesto, 0) <> nvl(v_val_exo_impuesto, 0)) or
                       (nvl(v_val_impuesto, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0) then
                    prg_ins_exoneracion(v_cod_tra_impuesto, pag_cta.G_CTAS.cod_modulo,
                                        pag_cta.G_CTAS.cod_modalidad, pag_cta.G_CTAS.cod_moneda,
                                        v_cta_cargo, null, v_cod_tas_impuesto,
                                        (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)),
                                         v_val_exo_impuesto, null,
                                        (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)));
                 end if;
              end if;
              ---
              if nvl(v_val_cargo, 0) > 0 then
                 -- Verifico si se puede debitar el total del cargo (cargo + Iva)
                 pag_cta.pr_ver_operacion(v_cta_cargo,
                                          v_cod_tra_cargo,       -- COD_TRA_PADRE
                                          v_cod_mod_padre,       --cod_mod_padre
                                          v_cod_mad_padre,       --cod_mad_padre
                                          'D',
                                          e.cod_moneda,                   --Moneda de la Operacion
                                          v_val_cargo + v_val_impuesto,   -- Valor del Cargo mas el impuesto
                                          v_cod_ofi_origen,               --cod_ofi_origen
                                          v_cod_modulo,
                                          v_cod_modalidad,
                                          v_nvo_estado,
                                          v_sal_disponible,
                                          v_procesado,
                                          v_cod_tra_cargo) ;

                 if pag_cta.fu_obt_cod_error() <> 0 or v_procesado = 'N' then
                    v_procesado  := 'N' ;
                 else
                     if v_nro_secuencia > 990 then
                        v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
                        v_nro_secuencia := -999;
                     end if;
                     -- Debito a la Cta. Recaudadora
                     pag_cta.pr_act_operacion(v_cta_cargo,
                                              v_hora,--HORA
                                              'D',
                                              e.cod_moneda,              --Moneda de la Operacion
                                              v_val_cargo,
                                              v_cod_tra_cargo,           -- COD_TRA_PADRE
                                              v_cod_tra_cargo,           -- COD_TRA_HIJO
                                              e.cod_ente,
                                              null,                      --COTIZACION
                                              v_cod_ofi_origen,          --cod_ofi_origen
                                              v_cod_mod_padre,           --cod_mod_padre
                                              v_cod_mad_padre,           --cod_mad_padre
                                              v_cod_tas_costo,           --cod_tasa
                                              v_val_tasa,                --val_tasa
                                              substr('Déb.por Cargo de Serv.Rec.'||v_cantidad,1,35),
                                             'S',                       --emi_aviso
                                             v_nro_secuencia,
                                             v_Fec_actual);

                     if pag_cta.fu_obt_cod_error() <> 0 then
                        v_procesado  := 'N' ;
                     else
                        v_procesado  := 'S' ;
                        if nvl(v_val_impuesto,0) > 0 then
                           --
                           PAG_CTA.PR_ACT_OPERACION(v_cta_cargo,        -- P_NRO_CUENTA
                                                    v_hora,             -- P_HORA
                                                    'D',                -- P_TIP_MOVIMIENTO
                                                    e.cod_moneda,       -- P_COD_MONEDA
                                                    v_val_impuesto,     -- P_MONTO
                                                    v_cod_tra_cargo,    -- P_COD_TRA_PADRE
                                                    v_cod_tra_impuesto, -- P_COD_TRANSACCION
                                                    e.cod_ente,         --P_NRO_DOCUMENTO
                                                    null,                --P_COTIZACION
                                                    v_cod_ofi_origen,    --cod_ofi_origen
                                                    v_cod_mod_padre,     --cod_mod_padre
                                                    v_cod_mad_padre,     --cod_mad_padre
                                                    v_cod_tas_impuesto,            --P_COD_TASA
                                                    v_val_tas_impuesto,            --P_VAL_TASA
                                                    substr('Imp.por Cargo de Serv.Rec.'||v_cantidad,1,35),  -- P_CONCEPTO
                                                    'S',                           -- p_EMI_AVISO
                                                    v_nro_secuencia,               -- P_NRO_SECUENCIA IN OUT
                                                    v_Fec_actual );

                           if pag_cta.fu_obt_cod_error() <> 0 then
                              raise_application_error(-20000,'Error en mov. impuesto '||v_cta_cargo||'-'||sqlerrm);
                           else
                              v_procesado  := 'S' ;
                           end if;
                       end if;
                    end if ;
                 end if;
              end if ;
              -- Si existe cargo y no pudo debitar genera movimiento pendiente
              if nvl(v_val_cargo, 0) > 0 and v_procesado = 'N' then
                 -- Si existe cargo a cobrar y no se puede procesar se debe generar movimiento pendiente.
                 lp_gen_mov_pendiente ;
              end if ;
           end if ;

         v_cod_tas_car_tot := null ;
         v_cod_tas_car_liq := null ;
         v_cod_tra_cargo   := null ;
         v_cta_cargo       := null ;
   v_cod_tas_costo   := null ;
      end loop;
   End ;


PROCEDURE PR_OBT_CARGOS
     (P_COD_OFI_ORIGEN IN GE_CUENTAS.COD_OFICINA%TYPE,
      P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
      P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE,
      P_CANTIDAD IN NUMBER,
      P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE,
      P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE,
      P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE,
      P_COD_TRA_CARGO IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE,
      P_IVA_INCLUIDO  IN VARCHAR2 DEFAULT 'S',
      P_COD_TAS_CARGO IN OUT GE_MOVIMIENTOS.COD_TASA%TYPE,
      P_VAL_TAS_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE,
      P_VAL_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE,
      P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE,
      P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE,
      P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE,
      P_VAL_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE )
 IS
v_val_base      number(18,2) := p_monto;
v_fec_vigencia  date;
v_tip_valor     varchar2(1);
v_tipo          varchar2(1);
v_redondeo      number(1);
v_tas_personalizada varchar2(1);
begin
  -- veo si la cuenta tiene transaccion prohibida
  if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                 p_cod_tra_cargo,
                                 p_cod_modulo,
                                 p_cod_modalidad) = 'N' then
    -- no tiene transaccion prohibida, se calcula
    begin
       select tas_personalizada
         into v_tas_personalizada
         from ge_cuentas
         where nro_cuenta = p_nro_cuenta;
    exception
       when others then
          v_tas_personalizada := 'N';
    end;
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',P_COD_MODULO,P_COD_MODALIDAD,P_cod_moneda);
    -- Se busca el tipo de tasa para indicar si es Porcentaje o Valor
    v_tip_valor := fug_obt_tip_val_tasa(p_cod_tas_cargo);
    -- busco el valor de la tasa
    if v_tip_valor = 'V' then
       pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
           p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
           p_cantidad, nvl(v_tas_personalizada,'N'), p_cod_tas_cargo,
           p_cod_tra_cargo, trunc(sysdate),
           p_val_tas_cargo, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT

       -- si es un valor, se toma el valor y se multiplica por la cantidad
       p_val_cargo := nvl(p_cantidad,1) * nvl(p_val_tas_cargo,0);
    else
        pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
           p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
           v_val_base, nvl(v_tas_personalizada,'N'), p_cod_tas_cargo,
           p_cod_tra_cargo, trunc(sysdate),
           p_val_tas_cargo, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
       -- es un porcentaje
       p_val_cargo := round(nvl(v_val_base,0)*
                               nvl(p_val_tas_cargo,0)/100,v_redondeo);
    end if;

    -- busco el impuesto asociado a este cargo
    begin
      select cod_tra_hijo
        into p_cod_tra_impuesto
        from ge_transacciones_det
       where cod_modulo = p_cod_modulo
         and cod_modalidad = p_cod_modalidad
         and cod_transaccion = p_cod_tra_cargo
         and cod_mod_hijo = p_cod_modulo
         and cod_mad_hijo = p_cod_modalidad
         and rownum = 1;
      -- veo si la cuenta tiene exoneracion de impuestos
      if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                      p_cod_tra_impuesto,
                                      p_cod_modulo,
                                      p_cod_modalidad) = 'N' then
         -- Se encontro impuesto asociado, se calcula
         pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
               p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
               p_val_cargo, nvl(v_tas_personalizada,'N'), p_cod_tas_impuesto,
               p_cod_tra_impuesto, trunc(sysdate),
               p_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
         if v_tip_valor = 'V' then
            -- si es un valor, se toma directamente
            p_val_impuesto := nvl(p_val_tas_impuesto,0);
         else
            --
            -- es un porcentaje, se considera incluido en el cargo
              p_val_impuesto := round(nvl(p_val_cargo,0)*
                                      nvl(p_val_tas_impuesto,0)/(100+p_val_tas_impuesto),v_redondeo);
         end if;

         -- resto el monto del impuesto al cargo, porque va incluido
         if nvl(p_iva_incluido,'S') = 'S' then
            p_val_cargo := nvl(p_val_cargo,0) - nvl(p_val_impuesto,0);
         end if;
         if p_val_cargo < 0 then
            raise_application_error(-20000,'Impuesto mas alto que el Cargo');
         end if;
       else
          p_val_impuesto := 0;
       end if;
    exception
       when others then
           p_val_impuesto := 0;
    end;
  end if;
end ;

FUNCTION FU_ACT_EST_RECAUDACION(P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE,
                                P_NRO_ARCHIVO IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                                P_FEC_OPERACION IN GE_PAG_RECAUDACIONES.FEC_OPERACION%TYPE,
                                P_ESTADO IN GE_PAG_RECAUDACIONES.ESTADO%TYPE) RETURN NUMBER IS
BEGIN
   UPDATE ge_pag_recaudaciones
      SET estado = p_estado
    WHERE cod_ente = p_cod_ente
      AND trunc(fec_operacion) = trunc(p_fec_operacion)
      AND nro_archivo = p_nro_archivo
      AND nvl(estado, 'x') <> 'E';

   RETURN SQL%ROWCOUNT;
EXCEPTION
   WHEN OTHERS THEN
      RETURN -99;
END;
FUNCTION FU_ELI_TEMPORAL(P_COD_ENTE      IN GE_ENTES.COD_ENTE%TYPE,
                         P_NRO_ARCHIVO   IN GE_PAG_RECAUDACIONES_TMP.NRO_ARCHIVO%TYPE,
                         P_FEC_OPERACION IN GE_PAG_RECAUDACIONES_TMP.FEC_OPERACION%TYPE) RETURN NUMBER IS
BEGIN
   DELETE FROM ge_pag_recaudaciones_tmp t
    WHERE t.cod_ente = P_COD_ENTE
      AND t.nro_archivo = P_NRO_ARCHIVO
      AND trunc(t.fec_operacion) = P_FEC_OPERACION;

   RETURN SQL%ROWCOUNT;
EXCEPTION
   WHEN OTHERS THEN
      RETURN - 9;
END;

FUNCTION FU_ELI_ERRORES(P_COD_ENTE      IN GE_ENTES.COD_ENTE%TYPE,
                        P_NRO_ARCHIVO   IN GE_PAG_RECAUDACIONES_TMP.NRO_ARCHIVO%TYPE,
                        P_FEC_OPERACION IN GE_PAG_RECAUDACIONES_TMP.FEC_OPERACION%TYPE) RETURN NUMBER IS
   v_cantidad NUMBER;
   v_retorno  NUMBER := 0;
BEGIN
   SELECT COUNT(0)
     INTO v_cantidad
     FROM ge_pag_recaudaciones p
    WHERE p.cod_ente = P_COD_ENTE
      AND p.nro_archivo = P_NRO_ARCHIVO
      AND p.fec_operacion = P_FEC_OPERACION;
   -- se borra unicamente si no existe pagos asociados
   IF v_cantidad = 0 THEN
      DELETE FROM ge_pag_recaudaciones_err t
       WHERE t.cod_ente = P_COD_ENTE
         AND t.nro_archivo = P_NRO_ARCHIVO
         AND trunc(t.fec_operacion) = P_FEC_OPERACION;
      v_retorno := SQL%ROWCOUNT;
   END IF;

   RETURN v_retorno;
EXCEPTION
   WHEN OTHERS THEN
      RETURN - 9;
END;

PROCEDURE PR_INS_GE_PAG_RECAUDACIONES(P_COD_ENTE      IN GE_PAG_RECAUDACIONES.COD_ENTE%TYPE,
                                      P_NRO_ARCHIVO   IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                                      P_FEC_OPERACION IN GE_PAG_RECAUDACIONES.FEC_OPERACION%TYPE,
                                      P_ERROR         OUT VARCHAR2) IS

BEGIN
   INSERT INTO ge_pag_recaudaciones
      (cod_ente, fec_operacion, nro_archivo, nro_cta_debito, denominacion, nro_cta_credito,
       cod_moneda, monto, estado, nro_factura, tip_cobranza)
      SELECT cod_ente, fec_operacion, nro_archivo, nro_cta_debito, denominacion, nro_cta_credito,
             cod_moneda, monto, estado, nro_factura, tip_cobranza
        FROM ge_pag_recaudaciones_tmp
       WHERE cod_ente = p_cod_ente
         AND trunc(fec_operacion) = trunc(p_fec_operacion)
         AND nro_archivo = p_nro_archivo;

   IF SQL%NOTFOUND THEN
      p_error := '-20099, Insertar en ge_pag_recaudaciones. No existen datos en el tmp';
   ELSE
      p_error := NULL;
   END IF;
EXCEPTION
   WHEN dup_val_on_index THEN
      p_error := '-20199, Registro ya existe en ge_pag_recaudaciones.';
END;

FUNCTION FU_VAL_FEC_PAGO(P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE,
                         P_FEC_PAGO IN DATE) RETURN NUMBER IS
   v_retorno  NUMBER := 0;
   v_dia_pago NUMBER;
   v_fec_operacion DATE := trunc(p_fec_pago);
BEGIN
   v_dia_pago := nvl(TRIM(fug_obt_parentes(p_cod_ente,'CAN_DIA_PAGO')), 90);

   if abs(pag_cal.FU_OBT_FEC_ACTUAL(1) - v_fec_operacion) > v_dia_pago then
      -- El periodo de tiempo entre la fecha actual y la fecha de pago no debe superar v_dia_pago dias.
      v_retorno := -1;
   elsif v_fec_operacion < pag_cal.FU_OBT_FEC_ACTUAL(1) or v_fec_operacion < trunc(sysdate) then
      -- La fecha de operacion no debe de ser menor a la fecha actual del sistema
      v_retorno := -2;
   elsif pag_cal.fu_obt_fec_habil(v_fec_operacion, 1, NULL) != v_fec_operacion then
      -- La fecha de operacion no es una fecha habil
      v_retorno := -3;
   end if;
   RETURN v_retorno;
END;

--Valida los datos de la importacion de datos.
PROCEDURE PR_VAL_TEMPORAL(P_COD_ENTE      IN GE_ENTES.COD_ENTE%TYPE,
                          P_FEC_OPERACION IN GE_CALENDARIOS.FEC_ACTUAL%TYPE,
                          P_NRO_ARCHIVO   IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                          P_PROCESO       IN VARCHAR2) IS
   v_cod_mon_cta_cre     ge_cuentas.cod_moneda%TYPE;
   v_cod_mon_cta_deb     ge_cuentas.cod_moneda%TYPE;
   v_dia_pago            NUMBER;
   --v_dia_diferencia      NUMBER;
   v_cta_recaudadora     VARCHAR2(1);
   v_cta_recaudadora_def VARCHAR2(15);
   v_exi_cta_credito     VARCHAR2(1);
   v_exi_cta_debito      VARCHAR2(1);
   v_exi_cta_deb_rec     VARCHAR2(1);
   v_procesa_cre         VARCHAR2(1);
   v_procesa_deb         VARCHAR2(1);
   v_cod_modulo          ge_modalidades.cod_modulo%TYPE;
   v_cod_modalidad       ge_modalidades.cod_modalidad%TYPE;
   v_sal_disponible      ge_cuentas.sal_contable%TYPE;
   v_estado              ge_cuentas.estado%TYPE;
   v_cod_per_ente        ge_entes.cod_persona%TYPE DEFAULT fue_obt_per_ente(p_cod_ente);
   v_cta_existente       VARCHAR2(1) DEFAULT 'N';
   v_redondeo            NUMBER(8);
   RG_GPREC              ge_pag_recaudaciones_err%ROWTYPE;
   v_cod_error           NUMBER;
   v_msj_error           ge_pag_recaudaciones_err.msj_error%TYPE;
   CURSOR c_rec IS
      SELECT t.nro_cta_credito, t.nro_cta_debito, t.cod_moneda, t.monto, t.fec_operacion, t.tip_cobranza
        FROM ge_pag_recaudaciones_tmp t
       WHERE t.cod_ente = P_COD_ENTE
         AND trunc(t.fec_operacion) = trunc(P_FEC_OPERACION)
         AND t.nro_archivo = P_NRO_ARCHIVO
         AND P_PROCESO = 'N'
       UNION
      SELECT r.nro_cta_credito, r.nro_cta_debito, r.cod_moneda, r.monto, r.fec_operacion, r.tip_cobranza
        FROM ge_pag_recaudaciones r
       WHERE r.cod_ente = P_COD_ENTE
         AND trunc(r.fec_operacion) = trunc(P_FEC_OPERACION)
         AND r.nro_archivo = P_NRO_ARCHIVO
         AND P_PROCESO = 'S';

   PROCEDURE pr_act_error(p_tip_cobranza IN ge_pag_recaudaciones.tip_cobranza%TYPE,
                          p_rg_gprec     IN ge_pag_recaudaciones_err%ROWTYPE) IS
   BEGIN
      --Verifica si es proceso de Pago o Importacion.

      IF P_PROCESO = 'S' THEN
         UPDATE ge_pag_recaudaciones r
            SET r.estado = 'E'
          WHERE r.cod_ente = p_rg_gprec.cod_ente
            AND r.fec_operacion = p_rg_gprec.fec_operacion
            AND r.nro_archivo = p_rg_gprec.nro_archivo
            AND r.nro_cta_debito = p_rg_gprec.nro_cta_debito
            AND r.nro_cta_credito = p_rg_gprec.nro_cta_credito
            AND r.tip_cobranza = p_tip_cobranza
            AND r.monto = p_rg_gprec.monto;
      ELSE
         UPDATE ge_pag_recaudaciones_tmp r
            SET r.estado = 'E'
          WHERE r.cod_ente = p_rg_gprec.cod_ente
            AND r.fec_operacion = p_rg_gprec.fec_operacion
            AND r.nro_archivo = p_rg_gprec.nro_archivo
            AND r.nro_cta_debito = p_rg_gprec.nro_cta_debito
            AND r.nro_cta_credito = p_rg_gprec.nro_cta_credito
            AND r.tip_cobranza = p_tip_cobranza
            AND r.monto = p_rg_gprec.monto;
      END IF;
      pag_rec.pr_ins_log(p_rg_gprec);
   END;
BEGIN
   RG_GPREC.COD_ENTE      := P_COD_ENTE;
   RG_GPREC.NRO_ARCHIVO   := P_NRO_ARCHIVO;
   RG_GPREC.Fec_Operacion := P_FEC_OPERACION;
   v_dia_pago             := fug_obt_parentes(p_cod_ente, 'CAN_DIA_PAGO');

   FOR c IN c_rec
   LOOP
      v_cod_error := 0;
      v_msj_error := null;

      --Trae la cuenta de credito de la parametrizacion por entes
      IF c.nro_cta_credito IS NULL THEN
         v_cta_recaudadora_def := fug_obt_parentes(p_cod_ente, 'NRO_CTA_RECAUDADORA_' || c.cod_moneda);
      END IF;
      --Verifica si existe la Cta. de Credito.
      BEGIN
         SELECT 'S'
           INTO v_exi_cta_credito
           FROM ge_cta_clientes cc
          WHERE (cc.nro_cuenta = c.nro_cta_credito OR cc.nro_cuenta = v_cta_recaudadora_def)
                AND cc.relacion = 'P';
      EXCEPTION
         WHEN no_data_found THEN
            v_exi_cta_credito := 'N';
         WHEN OTHERS THEN
            v_exi_cta_credito := 'N';
      END;
      IF v_exi_cta_credito = 'N' THEN
         v_cod_error := 12;
         v_msj_error := 'Nro. Cta. de Crédito ' || c.nro_cta_credito || ' inexistente. ';
      END IF;
      --Verifica si existe la Cta. Debito.
      BEGIN
         SELECT DISTINCT 'S'
           INTO v_exi_cta_debito
           FROM ge_cta_clientes cc
          WHERE cc.nro_cuenta = c.nro_cta_debito;
      EXCEPTION
         WHEN no_data_found THEN
            v_exi_cta_debito := 'N';
         WHEN OTHERS THEN
            v_exi_cta_debito := 'N';
      END;
      IF v_exi_cta_debito = 'N' THEN
         v_cod_error := 1; --12;
         v_msj_error := v_msj_error || 'Nro. Cta. de Débito ' || c.nro_cta_debito || ' inexistente. ';
      END IF;
      IF v_exi_cta_credito = 'S' AND v_exi_cta_debito = 'S' THEN
         --valida cuentas de credito.
         pag_cta.PR_OBT_CUENTA(nvl(c.nro_cta_credito, v_cta_recaudadora_def));
         BEGIN
            pag_cta.PR_VER_OPERACION(nvl(c.nro_cta_credito, v_cta_recaudadora_def), fug_obt_parentes(p_cod_ente, 'COD_TRA_PADRE'), pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.COD_MODALIDAD, 'C', c.cod_moneda, 0, pag_cta.G_CTAS.COD_OFICINA, v_cod_modulo, v_cod_modalidad, v_estado, v_sal_disponible, v_procesa_cre, NULL);
            IF v_procesa_cre = 'N' THEN
               v_cod_error := pag_cta.fu_obt_cod_error;
               v_msj_error := substr(pag_cta.fu_obt_msj_error, 1, 4000)||'. ';
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               v_procesa_cre := 'N';
               v_cod_error := 1;

               v_msj_error := 'No se puede operar sobre la cuenta credito. ';
         END;
         pag_cta.PR_OBT_CUENTA(c.nro_cta_debito);
         BEGIN
            pag_cta.PR_VER_OPERACION(c.nro_cta_debito, fug_obt_parentes(p_cod_ente, 'COD_TRA_PADRE'), pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.COD_MODALIDAD, 'D', c.cod_moneda, 0, pag_cta.G_CTAS.COD_OFICINA, v_cod_modulo, v_cod_modalidad, v_estado, v_sal_disponible, v_procesa_deb, NULL);
            IF pag_cta.fu_obt_cod_error IN (25, 29, 31, 36) THEN
               v_procesa_deb := 'S'; -- obviar los errores de saldo
            END IF;
            IF v_procesa_deb = 'N' THEN
               IF v_cod_error = 0 THEN
                  v_cod_error := 1; --pag_cta.fu_obt_cod_error;
               END IF;
               v_msj_error := substr(pag_cta.fu_obt_msj_error, 1, 4000)||'. ';
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               v_procesa_deb := 'N';
               v_cod_error := 1;
               v_msj_error := substr(v_msj_error||'No se puede operar sobre la cuenta debito. ', 1, 4000);
         END;
         v_cod_mon_cta_deb := fug_obt_mon_cta(c.nro_cta_debito);
         IF v_procesa_cre = 'S' AND v_procesa_deb = 'S' THEN
            --Verifica si la Cta. Credito corresponde al ente ingresado
            BEGIN
               SELECT DISTINCT 'S'
                 INTO v_cta_existente
                 FROM ge_cta_clientes a
                WHERE a.cod_persona = v_cod_per_ente
                      AND (a.nro_cuenta = c.nro_cta_credito OR a.nro_cuenta = v_cta_recaudadora_def);
            EXCEPTION
               WHEN no_data_found THEN
                  v_cta_existente := 'N';
               WHEN OTHERS THEN
                  v_cta_existente := 'N';
            END;

            IF v_cta_existente = 'N' THEN
              v_cod_error := 789;
              v_msj_error := 'Nro. Cta. de Crédito ' || c.nro_cta_credito || ' no corresponde al ente. ';
            END IF;
            --verifica si la cuenta de credito es recaudadora.
            BEGIN
               SELECT a.val_parametro
                 INTO v_cta_recaudadora
                 FROM ge_cta_dat_adicionales a
                WHERE (a.nro_cuenta = c.nro_cta_credito OR a.nro_cuenta = v_cta_recaudadora_def)
                      AND a.parametro = 'CTA_CRE_RECAUDADORA';
            EXCEPTION
               WHEN no_data_found THEN
                  v_cta_recaudadora := 'N';
               WHEN OTHERS THEN
                  v_cta_recaudadora := 'N';
            END;
            IF v_cta_recaudadora = 'N' and v_cod_error = 0 THEN
               v_cod_error := 567;
               v_msj_error := 'El Nro. de Cta. de Crédito ' || nvl(c.nro_cta_credito, v_cta_recaudadora_def) || ' no es recaudadora. ';
            END IF;
            --verifica si esta definido las cuentas de debitos en la tabla ge_cta_deb_recaudaciones
            BEGIN
               SELECT DISTINCT 'S'
                 INTO v_exi_cta_deb_rec
                 FROM ge_cta_deb_recaudaciones r
                WHERE r.nro_cta_debito = c.nro_cta_debito
                      AND r.cod_ente = P_COD_ENTE
                      AND r.activo = 'S';
            EXCEPTION
               WHEN no_data_found THEN
                  v_exi_cta_deb_rec := 'N';
               WHEN OTHERS THEN
                  v_exi_cta_deb_rec := 'N';
            END;
            IF v_exi_cta_deb_rec = 'N' THEN
               IF v_cod_error = 0 THEN
                  v_cod_error := 1; --101;
               END IF;
               v_msj_error := substr(v_msj_error||'Nro. Cta. de Débito ' || c.nro_cta_debito || ' no definida como cuenta de débito para el ente. ', 1, 4000);
            ELSE
               -- CR: validar solo la moneda si la cuenta es correcta
               IF c.nro_cta_credito IS NOT NULL THEN
                  v_cod_mon_cta_cre := fug_obt_mon_cta(c.nro_cta_credito);
               ELSE
                  v_cod_mon_cta_cre := fug_obt_mon_cta(v_cta_recaudadora_def);
               END IF;
               --verifica moneda entre cuentas de debito y credito.
               IF v_cod_mon_cta_cre <> v_cod_mon_cta_deb THEN
                  IF v_cod_error = 0 THEN
                     v_cod_error := 1; --123;
                  END IF;
                  v_msj_error := substr(v_msj_error||'Moneda incorrectas entre cuentas. ', 1, 4000);

               END IF;
            END IF;
         END IF;
      END IF;
      --verifica que el monto a importar sea mayor a 0.
      IF c.monto <= 0 THEN
         IF v_cod_error = 0 THEN
            v_cod_error := 2; --345;
         ELSIF v_cod_error = 1 THEN
            v_cod_error := 3;
         END IF;
         v_msj_error := substr(v_msj_error||'Monto no mayor a cero. ', 1, 4000);
      ELSE
         -- validamos los decimales
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, v_cod_mon_cta_deb);

         IF nvl(c.monto, 0) <> trunc(nvl(c.monto, 0), v_redondeo) THEN
            IF v_cod_error = 0 THEN
               v_cod_error := 2; --345;
            ELSIF v_cod_error = 1 THEN
               v_cod_error := 3;
            END IF;
            v_msj_error := substr(v_msj_error||'Cuenta debito no admite decimal. ', 1, 4000);
         END IF;
      END IF;
      -- validamos la fecha de pago
      IF v_cod_error = 0 THEN
         v_cod_error := FU_VAL_FEC_PAGO(p_cod_ente, c.fec_operacion);
         CASE v_cod_error
            WHEN 0 THEN
               NULL;
            WHEN -1 THEN
               v_cod_error := 456;
               v_msj_error := substr(v_msj_error||'La fecha de pago no debe superar ' || v_dia_pago || ' dias. ', 1, 4000);
            WHEN -2 THEN
               v_cod_error := 987;
               v_msj_error := substr(v_msj_error||'Fecha de operación invalida. ', 1, 4000);
            WHEN -3 THEN
               v_cod_error := 876;
               v_msj_error := substr(v_msj_error||'Fecha de operación debe ser habil. ', 1, 4000);
            ELSE
               v_msj_error := substr(v_msj_error||'Fecha de operación no controlada. ', 1, 4000);
         END CASE;
      END IF;
      -- si hay error, insertamos
      IF v_cod_error <> 0 THEN
         RG_GPREC.NRO_CTA_DEBITO := c.nro_cta_debito;
         RG_GPREC.Nro_Cta_Credito := nvl(c.nro_cta_credito,v_cta_recaudadora_def);
         RG_GPREC.Fec_Operacion := c.fec_operacion;
         RG_GPREC.NRO_ARCHIVO := P_NRO_ARCHIVO;
         RG_GPREC.MONTO := c.monto;
         RG_GPREC.COD_ERROR := v_cod_error;
         RG_GPREC.Msj_Error := v_msj_error;
         pr_act_error(c.tip_cobranza, RG_GPREC);
      END IF;
   END LOOP;
END;

PROCEDURE lp_ins_log_mensajeria(p_pedido IN bw_log_bca_electronica.mensaje%TYPE, p_respuesta IN bw_log_bca_electronica.respuesta%TYPE) IS
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   BEGIN
      INSERT INTO bw_log_bca_electronica
         (mensaje, respuesta)
      VALUES
         (p_pedido, p_respuesta);
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
END;

PROCEDURE LP_ENV_MAIL_DEBITO(p_dir_mail_deb   IN VARCHAR2,
                             p_nro_cta_debito IN ge_pag_recaudaciones.nro_cta_debito%TYPE,
                             p_monto          IN ge_pag_recaudaciones.monto%TYPE,
                             p_cod_moneda     IN ge_pag_recaudaciones.cod_moneda%TYPE,
                             p_tip_cobranza   IN ge_pag_recaudaciones.tip_cobranza%TYPE,
                             p_nro_factura    IN ge_pag_recaudaciones.nro_factura%TYPE,
                             p_nom_ente       IN VARCHAR2,
                             p_fec_operacion  IN DATE,
                             p_hora           IN VARCHAR2) IS
   v_number  NUMBER;
   v_mensaje VARCHAR2(3000);
   v_db_name          VARCHAR2(20);
BEGIN
   -- para control de envio de correo
   SELECT upper(sys_context('USERENV', 'DB_NAME'))
     INTO v_db_name
     FROM dual;

   -- Envio de mail al titular de cta debito.
   BEGIN
      IF p_dir_mail_deb IS NOT NULL AND fug_ind_produccion = 'S' THEN
         v_mensaje := '<h2 style="color:#074CA9; font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; margin-top:0px">DEBITO REALIZADO EN SU CUENTA</h2>
                       <p style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px">Estimado Cliente, le informamos que se realizo el debito en su Cuenta por el servicio de recaudaciones y cobranzas
                       solicitada por ' || p_nom_ente || '</p>';
         v_mensaje := v_mensaje || '
         <table width="500"; style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px;">
         <tbody>
           <tr>
              <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Fecha:</b></td>
              <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || to_char(p_fec_operacion, 'DD/MM/YYYY') || '</td>
           </tr>
           <tr>
              <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Hora:</b></td>
              <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || p_hora || '</td>
           </tr>
           <tr>
              <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Cuenta debito:</b></td>
              <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || p_nro_cta_debito || '</td>
           </tr>
           <tr>
              <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Monto:</b></td>
              <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || to_char(nvl(p_monto, 0), '999G999G999G999G999') || '</td>
           </tr>
           <tr>
              <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Moneda:</b></td>
              <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || p_cod_moneda || '</td>
           </tr>
           <tr>
              <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Concepto Cobro:</b></td>
              <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || fue_obt_des_refcodes('TIP_COB_RECAUDACION', p_tip_cobranza) || '</td>
           </tr>
           <tr>
              <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Nro. de Factura:</b></td>
              <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || p_nro_factura || '</td>
           </tr>
         </tbody>
         </table>
         <br />
         Atentamente.
         <br/>
         <p align="center" style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>';
         v_mensaje := '<div style="padding:20px 20px">' || v_mensaje || '</div>';
         v_number  := paw_not.fu_env_email_prueba(p_dir_mail_deb, v_mensaje, 'PAG_REC');
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
          lp_ins_log_mensajeria('env_mail_debito', Sqlerrm);
   END;
END;

PROCEDURE PR_COB_ONLINE(P_COD_ENTE        IN GE_PAG_RECAUDACIONES.COD_ENTE%TYPE,
                        P_FEC_OPERACION   IN GE_PAG_RECAUDACIONES.FEC_OPERACION%TYPE,
                        P_NRO_ARCHIVO     IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                        P_NRO_CTA_CREDITO IN GE_PAG_RECAUDACIONES.NRO_CTA_CREDITO%TYPE,
                        P_CANTIDAD        OUT NUMBER,
                        P_MTO_DEBITADO    OUT NUMBER,
                        P_CAN_ERROR       OUT NUMBER,
                        P_MTO_DEB_ERROR   OUT NUMBER,
                        P_MSJ_ERROR       OUT VARCHAR2) IS
   v_procesar         VARCHAR2(1) := 'S';
   v_ser_costo        VARCHAR2(10);
   v_fec_ini_contrato DATE;
   v_fec_fin_contrato DATE;
   v_cta_rec_gs       ge_cuentas.nro_cuenta%TYPE;
   v_cta_rec_usd      ge_cuentas.nro_cuenta%TYPE;
   v_cta_rec_eur      ge_cuentas.nro_cuenta%TYPE;
   v_cod_tra_padre    ge_transacciones.cod_transaccion%TYPE;
   v_ser_activo       VARCHAR2(1);
   v_can_dia_pago     VARCHAR2(10);
   v_cta_credito      ge_pag_recaudaciones.nro_cta_credito%TYPE;
   v_cod_mod_deb      ge_cuentas.cod_modulo%TYPE;
   v_cod_mad_deb      ge_cuentas.cod_modalidad%TYPE;
   v_cod_ofi_deb      ge_cuentas.cod_oficina%TYPE;
   v_cod_mon_deb      ge_cuentas.cod_moneda%TYPE;
   v_sal_disponible   ge_cuentas.sal_contable%TYPE;
   v_cod_mod_cre      ge_cuentas.cod_modulo%TYPE;
   v_cod_mad_cre      ge_cuentas.cod_modalidad%TYPE;
   v_cod_ofi_cre      ge_cuentas.cod_oficina%TYPE;
   v_cod_mon_cre      ge_cuentas.cod_moneda%TYPE;
   v_cod_error        ge_pag_recaudaciones_err.cod_error%TYPE := 0;
   v_msj_error        ge_pag_recaudaciones_err.msj_error%TYPE := NULL;
   v_observacion      ge_pag_recaudaciones_err.observacion%TYPE := NULL;
   v_fec_actual       DATE := pag_cal.fu_obt_fec_actual(1);
   v_hor_corte        VARCHAR2(8) := fug_obt_pardinamico('HOR_CIE_PAG_SER_RECAUDACION');
   v_hor_insercion    VARCHAR2(8);
   v_nvo_estado       ge_cuentas.estado%TYPE;
   v_hora             ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');
   v_nro_secuencia    ge_movimientos.nro_secuencia%TYPE := 0;
   v_nro_documento    ge_movimientos.nro_documento%TYPE;
   rg_gprec           ge_pag_recaudaciones_err%rowtype;

   -- cursor principal
   CURSOR c_recaudaciones IS
      SELECT *
        FROM ge_pag_recaudaciones a
       WHERE a.fec_operacion = p_fec_operacion
         AND a.estado = 'A'
         AND a.nro_archivo = p_nro_archivo
         AND a.cod_ente = p_cod_ente
         AND a.nro_cta_credito = p_nro_cta_credito
         FOR UPDATE;
BEGIN
   p_cantidad      := 0;
   p_mto_debitado  := 0;
   p_can_error     := 0;
   p_mto_deb_error := 0;

   -- obtenemos los datos del servicio del ente
   PR_OBT_DAT_SERVICIOS(p_cod_ente, null, p_nro_archivo, p_fec_operacion,
                           v_ser_costo, v_fec_ini_contrato, v_fec_fin_contrato, v_cta_rec_gs,
                           v_cta_rec_usd, v_cta_rec_eur, v_cod_tra_padre, v_ser_activo, v_can_dia_pago);

   IF nvl(v_ser_activo, 'N') = 'S' THEN
      IF p_nro_cta_credito IS NULL THEN
         v_procesar    := 'N';
         v_cod_error   := 333;
         v_msj_error   := 'No se encontró cuenta de Crédito para el Ente. ';
      ELSE
         v_cta_credito := p_nro_cta_credito;
         IF lf_val_cta_ente(p_cod_ente, v_cta_credito) = 'N' THEN
            v_procesar  := 'N';
            v_cod_error := 444;
            v_msj_error := 'Cuenta de Crédito inexistente o no es Recaudadora. ';
         END IF;
      END IF;
      -- validamos la fecha de pago
      IF v_cod_error = 0 THEN
         v_cod_error := fu_val_fec_pago(p_cod_ente, p_fec_operacion);
         v_procesar  := 'N';
         CASE v_cod_error
            WHEN 0 THEN
               v_procesar := 'S';
            WHEN -1 THEN
               v_msj_error := 'Fecha de pago excedida';
            WHEN -2 THEN
               v_msj_error := 'Fecha de pago invalida';
            WHEN -3 THEN
               v_msj_error := 'Fecha de pago no es habil';
            ELSE
               v_msj_error := 'Fecha no contemplada';
         END CASE;
      END IF;

      -- pre Proceso
      IF p_fec_operacion = v_fec_actual AND v_cod_error = 0 THEN
         v_hor_insercion := to_char(SYSDATE, 'hh24:mi');
         IF v_hor_insercion <= v_hor_corte THEN
            v_procesar := 'S';
         ELSE
            -- Verifica si es proceso Independiente y el ROL_PRO_PAG_POS_CORTE
            IF fug_val_usu_rol('ROL_PRO_PAG_POS_CORTE', USER) THEN
               v_procesar := 'S';
            ELSE
               v_procesar  := 'N';
               v_cod_error := 111;
               v_msj_error := 'Registro con hora de inserción mayor a la hora de Corte';
            END IF;
         END IF;
      END IF;


   ELSE
      v_procesar  := 'N';
      v_cod_error := 111;
      v_msj_error := 'Servicio Inactivo para el Ente. ';
   END IF;

   -- si hay error salimos
   IF v_cod_error <> 0 THEN
      P_MSJ_ERROR := substr(v_msj_error, 1, 200);
      RETURN;
   END IF;

   SELECT S_NRO_COM_RECAUDACIONES.NEXTVAL
     INTO v_nro_documento
     FROM dual;

   -- pag_cta.PR_SET_NRO_DOCUMENTO3(v_nro_documento);
   pag_cta.PR_SET_NRO_DOCUMENTO3(p_cod_ente);

   v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');

   -- Obtener datos cta credito
   BEGIN
      SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda
        INTO v_cod_mod_cre, v_cod_mad_cre, v_cod_ofi_cre, v_cod_mon_cre
        FROM ge_cuentas a
       WHERE a.nro_cuenta = v_cta_credito;
   EXCEPTION
      WHEN no_data_found THEN
         v_cod_mod_cre := NULL;
         v_cod_mad_cre := NULL;
         v_cod_ofi_cre := NULL;
         v_cod_mon_cre := NULL;
      WHEN OTHERS THEN
         v_cod_mod_cre := NULL;
         v_cod_mad_cre := NULL;
         v_cod_ofi_cre := NULL;
         v_cod_mon_cre := NULL;
   END;
   FOR k IN c_recaudaciones LOOP
      v_procesar    := 'S';
      v_cod_error   := 0;
      v_msj_error   := NULL;
      v_observacion := NULL;


      -- Obtener datos cta debito
      BEGIN
         SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda
           INTO v_cod_mod_deb, v_cod_mad_deb, v_cod_ofi_deb, v_cod_mon_deb
           FROM ge_cuentas a
          WHERE a.nro_cuenta = k.nro_cta_debito;
      EXCEPTION
         WHEN no_data_found THEN
            v_cod_mod_deb := NULL;
            v_cod_mad_deb := NULL;
            v_cod_ofi_deb := NULL;
            v_cod_mon_deb := NULL;
         WHEN OTHERS THEN
            v_cod_mod_deb := NULL;
            v_cod_mad_deb := NULL;
            v_cod_ofi_deb := NULL;
            v_cod_mon_deb := NULL;
      END;

      -- Inicio de procesos debitos - creditos.
      IF v_procesar = 'S' THEN
         -- Verifica la operacion de debito
         pag_cta.pr_ver_operacion(k.nro_cta_debito, v_cod_tra_padre, v_cod_mod_cre,
                                   -- se utiliza como módulo padre el de la cta crédito
                                  v_cod_mad_cre,
                                   -- se utiliza como modalidad padre el de la cta crédito
                                  'D', v_cod_mon_deb, k.monto, v_cod_ofi_deb,
                                  -- out
                                  pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, v_nvo_estado, v_sal_disponible, v_procesar, 503);
         IF pag_cta.g_cod_error <> 0 OR v_procesar = 'N' THEN
            v_cod_error   := pag_cta.FU_OBT_COD_ERROR;
            v_msj_error   := substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 4000);
            v_observacion := 'Verificacion operacion de debito';
            v_procesar    := 'N';
         END IF;
         IF v_procesar = 'S' THEN
            -- Verifica la operacion de credito
            pag_cta.pr_ver_operacion(k.nro_cta_credito, v_cod_tra_padre, v_cod_mod_cre, v_cod_mad_cre, 'C', v_cod_mon_cre, k.monto, v_cod_ofi_cre,
                                     -- out
                                     pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, v_nvo_estado, v_sal_disponible, v_procesar, 602);
            IF pag_cta.g_cod_error <> 0 OR v_procesar = 'N' THEN
               v_cod_error   := pag_cta.FU_OBT_COD_ERROR;
               v_msj_error   := substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 4000);
               v_observacion := 'Verificacion operacion de credito';
               v_procesar    := 'N';
            END IF;
         END IF;

         IF v_procesar = 'S' THEN

            IF v_nro_secuencia > 997 THEN
               v_nro_secuencia := -999;
            END IF;

            pag_cta.PR_SET_REFERENCIA(substr(k.nro_factura, 1, 20));
            --Actualizar el Saldo cta debito
            pag_cta.pr_act_operacion(k.nro_cta_debito,
                                     v_hora,
                                     'D',
                                     pag_cta.g_ctas.cod_moneda,
                                     k.monto,
                                     v_cod_tra_padre,
                                     503,
                                     v_nro_documento /*k.cod_ente*/, --nro documento
                                     NULL,
                                     fug_obt_ofi_usuario(USER), --cod_ofi_origen
                                     v_cod_mod_cre, --cod_mod_padre
                                     v_cod_mad_cre, --cod_mad_padre
                                     NULL, --cod_tasa
                                     NULL, --val_tasa
                                     substr('DEBITO POR ' || fue_obt_des_refcodes('TIP_COB_RECAUDACION', k.tip_cobranza), 1, 99),
                                     'S', --emi_aviso
                                     v_nro_secuencia,
                                     v_fec_actual);

            IF pag_cta.fu_obt_cod_error() <> 0 THEN
               v_procesar    := 'N';
               v_cod_error   := pag_cta.FU_OBT_COD_ERROR;
               v_msj_error   := substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 4000);
               v_observacion := 'Realizando debito. ';
            END IF;

            IF v_procesar = 'S' THEN
               p_cantidad := p_cantidad + 1;
               p_mto_debitado := p_mto_debitado + k.monto;

               -- Actualiza el estado a N = Procesado.
               UPDATE ge_pag_recaudaciones a
                  SET a.estado        = 'N',
                      a.nro_documento = v_nro_documento
                WHERE CURRENT OF c_recaudaciones;
            END IF;
         END IF;
      END IF;
      IF v_procesar = 'N' THEN
         p_mto_deb_error := p_mto_deb_error + k.monto;
         p_can_error     := p_can_error + 1;
         -- Actualiza el estado a E = Cancelado por Error.
         UPDATE ge_pag_recaudaciones a
            SET a.estado        = 'E',
                a.nro_documento = v_nro_documento
          WHERE CURRENT OF c_recaudaciones;

         rg_gprec.cod_ente        := k.cod_ente;
         rg_gprec.nro_cta_debito  := k.nro_cta_debito;
         rg_gprec.nro_cta_credito := k.nro_cta_credito;
         rg_gprec.fec_operacion   := k.fec_operacion;
         rg_gprec.nro_archivo     := k.nro_archivo;
         rg_gprec.monto           := k.monto;
         rg_gprec.cod_error       := v_cod_error;
         rg_gprec.msj_error       := v_msj_error;
         rg_gprec.observacion     := v_observacion;
         PR_INS_LOG(rg_gprec);
      END IF;
   END LOOP;

   IF P_MTO_DEBITADO > 0 THEN
      --Actualizar el Saldo cta Credito
      pag_cta.pr_act_operacion(p_nro_cta_credito,
                               v_hora,
                               'C',
                               pag_cta.g_ctas.cod_moneda,
                               p_mto_debitado,
                               v_cod_tra_padre,
                               602,
                               v_nro_documento /*p_cod_ente*/, --nro documento
                               NULL,
                               fug_obt_ofi_usuario(USER), --cod_ofi_origen
                               v_cod_mod_cre, --cod_mod_padre
                               v_cod_mad_cre, --cod_mad_padre
                               NULL, --cod_tasa
                               NULL, --val_tasa
                               substr('CREDITO POR RECAUDACIONES EN FECHA ' || to_char(p_fec_operacion, 'dd/mm/yyyy')/* || fue_obt_des_refcodes('TIP_COB_RECAUDACION', k.tip_cobranza)*/, 1, 99),
                               'S', --emi_aviso
                               v_nro_secuencia,
                               v_fec_actual);
      IF pag_cta.fu_obt_cod_error() <> 0 THEN
         rg_gprec.cod_ente        := p_cod_ente;
         rg_gprec.nro_cta_debito  := NULL;
         rg_gprec.nro_cta_credito := P_NRO_CTA_CREDITO;
         rg_gprec.fec_operacion   := p_fec_operacion;
         rg_gprec.nro_archivo     := p_nro_archivo;
         rg_gprec.monto           := p_mto_debitado;
         rg_gprec.cod_error       := pag_cta.FU_OBT_COD_ERROR;
         rg_gprec.msj_error       := pag_cta.FU_OBT_MSJ_ERROR;
         rg_gprec.observacion     := 'En Operación de Crédito.';
         p_msj_error              := substr(rg_gprec.msj_error, 1, 250);
         pr_ins_log(rg_gprec);
      ELSE -- realizamos la notificacion
        -- pr_env_notificacion(p_cod_ente, p_fec_operacion, p_nro_archivo, p_nro_cta_credito);
        null;
      END IF;
   END IF;
   pag_cta.PR_SET_NRO_DOCUMENTO3(NULL);
EXCEPTION
   WHEN OTHERS THEN
      p_msj_error := substr(SQLERRM, 1, 250);
      pag_cta.PR_SET_NRO_DOCUMENTO3(NULL);
END;

PROCEDURE PR_ENV_NOTIFICACION IS
      -- envio de notificacion
   v_nom_ente        ge_entes.descripcion%TYPE;
   v_cod_per_debito  ge_cta_clientes.cod_persona%TYPE;
   v_dir_mail_deb    ba_personas.dir_correo%TYPE;
   v_nom_cli_debito  ba_personas.nom_completo%TYPE;
   -- para envio de correo

   CURSOR c_recaudaciones IS
      SELECT *
        FROM ge_pag_recaudaciones a
       WHERE trunc(a.fec_operacion) = trunc(pag_cal.fu_obt_fec_actual(9))
         AND a.estado = 'N';
BEGIN
      -- obtenemos los datos del ente
   FOR re in c_recaudaciones LOOP
      v_nom_ente        := fue_obt_nom_ente(re.cod_ente);
      v_cod_per_debito := fug_obt_cli_principal(re.nro_cta_debito);
      v_dir_mail_deb   := fug_obt_dir_mail_per(v_cod_per_debito);
      v_nom_cli_debito := fue_obt_nom_persona(v_cod_per_debito);
      IF re.estado = 'N' THEN
         lp_env_mail_debito(v_dir_mail_deb, re.nro_cta_debito, re.monto, re.cod_moneda, re.tip_cobranza, re.nro_factura, v_nom_ente, re.fec_operacion, to_char(re.fec_insercion, 'hh24:mi'));

      END IF;
   END LOOP;
END;
--procesa el cobro cargando varios debitos y un solo credito por el total
--Se llama en el proceso independiente 99- SERVICIO DE RECAUDACIONES y en el cierre 107-PROCESO SERVICIO DE RECAUDACIONES
PROCEDURE PR_COB_SER_REC(P_CIERRE IN VARCHAR2 DEFAULT 'S',
                         P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL,
                         P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE DEFAULT NULL)
   IS

   v_procesar         varchar2(1) default 'S';
   v_ser_costo        varchar2(10);
   v_fec_ini_contrato date;
   v_fec_fin_contrato date;
   v_cta_rec_gs       ge_cuentas.nro_cuenta%type;
   v_cta_rec_usd      ge_cuentas.nro_cuenta%type;
   v_cta_rec_eur      ge_cuentas.nro_cuenta%type;
   v_cod_tra_padre    ge_transacciones.cod_transaccion%type;
   v_ser_activo       varchar2(1);
   v_can_dia_pago     varchar2(10);
   v_sal_disponible   ge_cuentas.sal_contable%type;
   v_nvo_estado       ge_cuentas.estado%type;
   v_hora             ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');
   v_nro_secuencia    ge_movimientos.nro_secuencia%type default 0;
   v_nro_documento    ge_movimientos.nro_documento%type;

   v_fec_actual       date default pag_cal.fu_obt_fec_actual(1);
   v_hor_corte        varchar2(8) default fug_obt_pardinamico('HOR_CIE_PAG_SER_RECAUDACION');
   v_hor_insercion    varchar2(8);


   v_cta_credito      ge_pag_recaudaciones.nro_cta_credito%type;

   v_cod_mod_deb      ge_cuentas.cod_modulo%type;
   v_cod_mad_deb      ge_cuentas.cod_modalidad%type;
   v_cod_ofi_deb      ge_cuentas.cod_oficina%type;
   v_cod_mon_deb      ge_cuentas.cod_moneda%type;

   v_cod_mod_cre      ge_cuentas.cod_modulo%type;
   v_cod_mad_cre      ge_cuentas.cod_modalidad%type;
   v_cod_ofi_cre      ge_cuentas.cod_oficina%type;
   v_cod_mon_cre      ge_cuentas.cod_moneda%type;

   v_cod_per_debito   ge_cta_clientes.cod_persona%type;
   v_cod_per_credito  ge_cta_clientes.cod_persona%type;
   v_nom_ente         ge_entes.descripcion%type;
   v_dir_mail_deb     ba_personas.dir_correo%type;
   v_dir_mail_cre     ba_personas.dir_correo%type;
   v_nom_cli_debito   ba_personas.nom_completo%type;

   rg_gprec           ge_pag_recaudaciones_err%rowtype;
   v_mto_debitado     ge_pag_recaudaciones.monto%type;
   v_nro_cta_credito  ge_pag_recaudaciones.nro_cta_credito%type;
   v_cod_ente         ge_pag_recaudaciones.cod_ente%type;
   v_tip_cobranza     ge_pag_recaudaciones.tip_cobranza%type;
   v_fec_operacion    ge_pag_recaudaciones.fec_operacion%type;
   v_nro_archivo      ge_pag_recaudaciones.nro_archivo%type;
   v_cont             number(18) := 0;
   v_hab_reintento    varchar2(1) default 'N';
   v_nro_registro     number(18);
   v_cod_tip_cobranza varchar(3);
   v_concepto varchar2(300);



     -- Variables para mail
  v_db_name  VARCHAR2(20);

   --01/08 Creado para agrupar los datos a procesar.
  Cursor c_principal is
   select distinct a.fec_operacion,a.cod_ente,a.cod_moneda,a.nro_archivo
       from ge_pag_recaudaciones a
      where a.fec_operacion <= v_fec_actual
        and a.estado = 'A'
        and (a.nro_cta_debito = p_nro_cuenta or p_nro_cuenta IS NULL)
        and (a.cod_ente = p_cod_ente or p_cod_ente IS NULL)
        order by a.fec_operacion,a.cod_ente,a.cod_moneda,a.nro_archivo;

   CURSOR c_rec(p_fec_operacion date, p_cod_ente_pri number,p_cod_moneda varchar2, p_nro_archivo number) is
     select *
       from ge_pag_recaudaciones a
      where a.estado = 'A'
        and trunc(a.fec_operacion)=trunc(p_fec_operacion)
        and a.cod_ente= p_cod_ente_pri
        and a.cod_moneda=p_cod_moneda
        and a.nro_archivo=p_nro_archivo
        --and (a.nro_cta_debito = p_nro_cuenta or p_nro_cuenta IS NULL)
        --and (a.cod_ente = p_cod_ente or p_cod_ente IS NULL)
        order by a.fec_operacion,a.cod_ente,a.cod_moneda,a.nro_archivo
     for update;

   BEGIN
     select upper(sys_context('USERENV', 'DB_NAME'))
       into v_db_name
       from dual;
 for z in c_principal loop
     v_mto_debitado:=0;
     v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
     v_nro_registro:=0;
     v_procesar:='N';
     for k in c_rec(z.fec_operacion, z.cod_ente,z.cod_moneda,z.nro_archivo) loop
       v_procesar:='S';
       v_cod_tip_cobranza:= null;
       v_cod_tip_cobranza:= k.tip_cobranza;
       v_nro_documento:=null;
       v_nro_registro:= nvl(v_nro_registro,0) +1;
       v_nro_documento:= v_nro_registro;
       --> DYDMR-2626
       rg_gprec.cod_error       := null;
       --<
       PR_OBT_DAT_SERVICIOS(k.cod_ente,
                            k.nro_cta_debito,
                            k.nro_archivo,
                            k.fec_operacion,
                            v_ser_costo,
                            v_fec_ini_contrato,
                            v_fec_fin_contrato,
                            v_cta_rec_gs,
                            v_cta_rec_usd,
                            v_cta_rec_eur,
                            v_cod_tra_padre,
                            v_ser_activo,
                            v_can_dia_pago);
       if nvl(v_ser_activo,'N') = 'S' then
         if k.nro_cta_credito is null then
           if k.cod_moneda = 'GS' then
             v_cta_credito := v_cta_rec_gs;
           elsif k.cod_moneda = 'USD' then
             v_cta_credito := v_cta_rec_usd;
           elsif k.cod_moneda = 'EUR' then
             v_cta_credito := v_cta_rec_eur;
           end if;

           if v_cta_credito is not null then
             -- Se valida que la cta sea del ente y este como recaudadora.
             if lf_val_cta_ente(k.cod_ente,v_cta_credito) = 'N' then

               v_procesar := 'N';
               rg_gprec.cod_ente        := k.cod_ente;
               rg_gprec.nro_cta_debito  := k.nro_cta_debito;
               rg_gprec.nro_cta_credito := k.nro_cta_credito;
               rg_gprec.fec_operacion   := k.fec_operacion;
               rg_gprec.nro_archivo     := k.nro_archivo;
               rg_gprec.monto           := k.monto;
               rg_gprec.cod_error       := 444;
               rg_gprec.msj_error       := 'La cuenta de Crédito no existe o no está marcado como Cuenta Recaudadora.';
               rg_gprec.observacion     := null;
               rg_gprec.nro_factura     := k.nro_factura;
               rg_gprec.cod_moneda      := k.cod_moneda;
               rg_gprec.tip_cobranza    := k.tip_cobranza;
               PR_INS_LOG(rg_gprec);
             end if;
           else
             v_procesar := 'N';
             rg_gprec.cod_ente        := k.cod_ente;
             rg_gprec.nro_cta_debito  := k.nro_cta_debito;
             rg_gprec.nro_cta_credito := k.nro_cta_credito;
             rg_gprec.fec_operacion   := k.fec_operacion;
             rg_gprec.nro_archivo     := k.nro_archivo;
             rg_gprec.monto           := k.monto;
             rg_gprec.cod_error       := 333;
             rg_gprec.msj_error       := 'No se encontró cuenta de Crédito para el Ente.';
             rg_gprec.observacion     := null;
             rg_gprec.nro_factura     := k.nro_factura;
             rg_gprec.cod_moneda      := k.cod_moneda;
             rg_gprec.tip_cobranza    := k.tip_cobranza;
             PR_INS_LOG(rg_gprec);
           end if;
         else
          v_cta_credito := k.nro_cta_credito;
          if lf_val_cta_ente(k.cod_ente,v_cta_credito) = 'N' then
            v_procesar := 'N';
            rg_gprec.cod_ente        := k.cod_ente;
            rg_gprec.nro_cta_debito  := k.nro_cta_debito;
            rg_gprec.nro_cta_credito := k.nro_cta_credito;
            rg_gprec.fec_operacion   := k.fec_operacion;
            rg_gprec.nro_archivo     := k.nro_archivo;
            rg_gprec.monto           := k.monto;
            rg_gprec.cod_error       := 444;
            rg_gprec.msj_error       := 'La cuenta de Crédito (de archivo) no existe o no está marcado como Cuenta Recaudadora.';
            rg_gprec.observacion     := null;
            rg_gprec.nro_factura     := k.nro_factura;
            rg_gprec.cod_moneda      := k.cod_moneda;
            rg_gprec.tip_cobranza    := k.tip_cobranza;
            PR_INS_LOG(rg_gprec);
          end if;
         end if;
         -- pre Proceso
         if k.fec_operacion = v_fec_actual then
           v_hor_insercion := to_char(/*k.fec_insercion*/sysdate,'hh24:mi');
           if v_hor_insercion <= v_hor_corte then
             v_procesar := 'S';
           else
             -- Verifica si es proceso Independiente y el ROL_PRO_PAG_POS_CORTE
             if (p_cierre = 'N' and fug_val_usu_rol('ROL_PRO_PAG_POS_CORTE',user))
                 OR p_cierre = 'S' then
               v_procesar := 'S';
             else
               v_procesar := 'N';
               rg_gprec.cod_ente        := k.cod_ente;
               rg_gprec.nro_cta_debito  := k.nro_cta_debito;
               rg_gprec.nro_cta_credito := k.nro_cta_credito;
               rg_gprec.fec_operacion   := k.fec_operacion;
               rg_gprec.nro_archivo     := k.nro_archivo;
               rg_gprec.monto           := k.monto;
               rg_gprec.cod_error       := 222;
               rg_gprec.msj_error       := 'Registro con hora de inserción mayor a la hora de Corte. Usuario: '||user;
               rg_gprec.observacion     := null;
               rg_gprec.nro_factura     := k.nro_factura;
               rg_gprec.cod_moneda      := k.cod_moneda;
               rg_gprec.tip_cobranza    := k.tip_cobranza;
               PR_INS_LOG(rg_gprec);
             end if;
           end if;
         end if;
       else
         v_procesar := 'N';
         rg_gprec.cod_ente        := k.cod_ente;
         rg_gprec.nro_cta_debito  := k.nro_cta_debito;
         rg_gprec.nro_cta_credito := k.nro_cta_credito;
         rg_gprec.fec_operacion   := k.fec_operacion;
         rg_gprec.nro_archivo     := k.nro_archivo;
         rg_gprec.monto           := k.monto;
         rg_gprec.cod_error       := 111;
         rg_gprec.msj_error       := 'Servicio Inactivo para el Ente.';
         rg_gprec.observacion     := null;
         rg_gprec.nro_factura     := k.nro_factura;
         rg_gprec.cod_moneda      := k.cod_moneda;
         rg_gprec.tip_cobranza    := k.tip_cobranza;
         PR_INS_LOG(rg_gprec);
       end if;
       -- Obtener datos cta debito
       begin
         select a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda
           into v_cod_mod_deb, v_cod_mad_deb, v_cod_ofi_deb, v_cod_mon_deb
           from ge_cuentas a
          where a.nro_cuenta = k.nro_cta_debito;
       exception
         when no_data_found then
         v_cod_mod_deb := null;
         v_cod_mad_deb := null;
         v_cod_ofi_deb := null;
         v_cod_mon_deb := null;
         when others then
         v_cod_mod_deb := null;
         v_cod_mad_deb := null;
         v_cod_ofi_deb := null;
         v_cod_mon_deb := null;
       end;

       -- Obtener datos cta credito
       begin
         select a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda
           into v_cod_mod_cre, v_cod_mad_cre, v_cod_ofi_cre, v_cod_mon_cre
           from ge_cuentas a
          where a.nro_cuenta = k.nro_cta_credito;
       exception
         when no_data_found then
         v_cod_mod_cre := null;
         v_cod_mad_cre := null;
         v_cod_ofi_cre := null;
         v_cod_mon_cre := null;
         when others then
         v_cod_mod_cre := null;
         v_cod_mad_cre := null;
         v_cod_ofi_cre := null;
         v_cod_mon_cre := null;
       end;
       -- Inicio de procesos debitos - creditos.
       if v_procesar = 'S' then
         --PCCMCSEG-3 AT- Automatizacion de Cobranzas para Seguros
         v_hab_reintento:='N';
         v_hab_reintento:= nvl(fug_obt_parentes(k.cod_ente, 'HAB_REI_COB_SR'),'N');
         IF /*k.tip_cobranza = 4 and*/ v_hab_reintento ='S' and nvl(v_cont,0) = 0 THEN
           BEGIN
             --Se busca y se cera por Tipo de Cobranza
             --v_cont := 0;
             select count(*)
               INTO v_cont
               from ge_mov_pen_cobranzas a
              where trunc(a.fecha) <= trunc(v_fec_actual)--desde fecha de implementacion
                and a.hora <> v_hora
                and a.estado = 'I'
                and a.cod_moneda= k.cod_moneda
                and nvl(trim(a.referencia),k.tip_cobranza) = k.tip_cobranza
                and to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))) = k.cod_ente;
                --and a.concepto like '%Cobranza de Seguros.%';
           EXCEPTION
             when others then
               v_cont := 1;
           END;
           IF v_cont > 0 THEN
              update ge_mov_pen_cobranzas a
                 set a.estado = 'X',
                     a.observacion = 'Pago re-enviado por el Cliente.',--'Pago re-enviado por la aseguradora.',
                     a.saldo = 0
               where trunc(a.fecha) <= trunc(v_fec_actual)--Menor a hoy
                 and a.hora <> v_hora
                 and a.estado = 'I'
                 and a.cod_moneda= k.cod_moneda
                 and nvl(trim(a.referencia),k.tip_cobranza) = k.tip_cobranza
                 and to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))) = k.cod_ente;
                 --and a.concepto like '%Cobranza de Seguros.%';
           END IF;
           v_cont := 1;
         END IF;
         -- Verifica la operación de débito
         pag_cta.pr_ver_operacion(k.nro_cta_debito,
                                  v_cod_tra_padre,
                                  v_cod_mod_cre, -- se utiliza como módulo padre el de la cta crédito
                                  v_cod_mad_cre, -- se utiliza como modalidad padre el de la cta crédito
                                  'D',
                                  v_cod_mon_deb,
                                  k.monto,
                                  v_cod_ofi_deb,
                                  -- out
                                  pag_cta.g_ctas.cod_modulo,
                                  pag_cta.g_ctas.cod_modalidad,
                                  v_nvo_estado,
                                  v_sal_disponible,
                                  v_procesar,
                                  503);
           if pag_cta.g_cod_error <> 0 or v_procesar = 'N' then
             rg_gprec.cod_ente        := k.cod_ente;
             rg_gprec.nro_cta_debito  := k.nro_cta_debito;
             rg_gprec.nro_cta_credito := k.nro_cta_credito;
             rg_gprec.fec_operacion   := k.fec_operacion;
             rg_gprec.nro_archivo     := k.nro_archivo;
             rg_gprec.monto           := k.monto;
             rg_gprec.cod_error       := pag_cta.FU_OBT_COD_ERROR;
             rg_gprec.msj_error       := pag_cta.FU_OBT_MSJ_ERROR;
             rg_gprec.observacion     := 'En verificación de Operación de Débito.';
             rg_gprec.nro_factura     := k.nro_factura;
             rg_gprec.cod_moneda      := k.cod_moneda;
             rg_gprec.tip_cobranza    := k.tip_cobranza;
             PR_INS_LOG(rg_gprec);
             --PCCMCSEG-3 AT- Automatizacion de Cobranzas para Seguros
             IF pag_cta.g_cod_error IN (25, 29, 31, 36) /*and k.tip_cobranza = 4*/ and v_hab_reintento='S' THEN
               v_concepto:=null;
               if NVL(k.tip_cobranza,4) = 4 then
                 v_concepto:='Cobranza de Seguros.';
               else
                 v_concepto:='Cobranza de Clientes.';
               end if;
              -- No dispone de saldo suficiente
               BEGIN
                  --Insertamos el tipo de Cobranza, se validara que sea obligatorio
                  INSERT INTO ge_mov_pen_cobranzas
                     (cod_usuario, hora, cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                      cod_moneda, cod_tra_padre, cod_transaccion, fecha, monto, estado,
                      cod_ofi_origen, cod_tasa, val_tasa, cod_mod_padre, cod_mad_padre,
                      nro_documento, concepto, saldo, car_manual,observacion, referencia)
                  VALUES
                     (USER, v_hora, pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                      pag_cta.g_ctas.cod_oficina, k.nro_cta_debito, pag_cta.g_ctas.cod_moneda,
                      v_cod_tra_padre, 503, v_fec_actual, k.monto, 'I',
                      31/*v_cod_ofi_deb*/, NULL/*665*/, 0, 3,31, k.nro_documento,
                      k.cod_ente||' - '||v_concepto, k.monto, 'N', to_char(v_nro_documento)||' - '||' Corresponde a Nro.Doc.: '||trim(k.nro_factura)
                      ,k.tip_cobranza);
               EXCEPTION
                  WHEN OTHERS THEN
                    null;
               END;
             /*ELSE -- comentado error cierre 24/11/2015 DYDMR-2626
               rg_gprec.observacion := substr(pag_cta.g_cod_error || '-' || pag_cta.g_msj_error,1,4000);
               PR_INS_LOG(rg_gprec);*/
             END IF;
           end if;
           if v_procesar = 'S' then
             ---     
			 if v_nro_secuencia > 995 then
				v_nro_secuencia := 1;
				v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
			 end if;
				 -- Verifica la operacion de credito
             pag_cta.pr_ver_operacion(k.nro_cta_credito,
                                      v_cod_tra_padre,
                                      v_cod_mod_cre,
                                      v_cod_mad_cre,
                                      'C',
                                      v_cod_mon_cre,
                                      k.monto,
                                      v_cod_ofi_cre,
                                      -- out
                                      pag_cta.g_ctas.cod_modulo,
                                      pag_cta.g_ctas.cod_modalidad,
                                      v_nvo_estado,
                                      v_sal_disponible,
                                      v_procesar,
                                      602);
             if pag_cta.g_cod_error <> 0 or v_procesar = 'N' then
               rg_gprec.cod_ente        := k.cod_ente;
               rg_gprec.nro_cta_debito  := k.nro_cta_debito;
               rg_gprec.nro_cta_credito := k.nro_cta_credito;
               rg_gprec.fec_operacion   := k.fec_operacion;
               rg_gprec.nro_archivo     := k.nro_archivo;
               rg_gprec.monto           := k.monto;
               rg_gprec.cod_error       := pag_cta.FU_OBT_COD_ERROR;
               rg_gprec.msj_error       := pag_cta.FU_OBT_MSJ_ERROR;
               rg_gprec.observacion     := 'En verificación de Operación de Crédito.';
               rg_gprec.nro_factura     := k.nro_factura;
               rg_gprec.cod_moneda      := k.cod_moneda;
               rg_gprec.tip_cobranza    := k.tip_cobranza;
               PR_INS_LOG(rg_gprec);
             end if;
           end if;

           if v_procesar = 'S' then
			 ---
             if v_nro_secuencia > 995 then
               v_nro_secuencia := 1;
	           v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
             end if;
			 ---
             v_nro_documento:=null;
             select S_NRO_COM_RECAUDACIONES.NEXTVAL
               into v_nro_documento
               from dual;

             pag_cta.PR_SET_NRO_DOCUMENTO3(k.cod_ente);
             pag_cta.PR_SET_REFERENCIA(substr(k.nro_factura,1,20));

             --Actualizar el Saldo cta debito
             pag_cta.pr_act_operacion(k.nro_cta_debito,
                    v_hora,
                    'D',
                    pag_cta.g_ctas.cod_moneda,
                    k.monto,
                    v_cod_tra_padre,
                    503,
                    v_nro_documento,          --nro documento
                    null,
                    fug_obt_ofi_usuario(user), --cod_ofi_origen
                    v_cod_mod_cre,             --cod_mod_padre
                    v_cod_mad_cre,             --cod_mad_padre
                    null,                      --cod_tasa
                    null,                      --val_tasa
                    substr('DÉBITO POR '||fue_obt_des_refcodes('TIP_COB_RECAUDACION', k.tip_cobranza)||' '||fue_obt_nom_ente(k.cod_ente),1,99) ,
                    'S',                       --emi_aviso
                    v_nro_secuencia,
                    v_fec_actual);
             if pag_cta.fu_obt_cod_error() <> 0 then
               v_procesar := 'N';
               rg_gprec.cod_ente        := k.cod_ente;
               rg_gprec.nro_cta_debito  := k.nro_cta_debito;
               rg_gprec.nro_cta_credito := k.nro_cta_credito;
               rg_gprec.fec_operacion   := k.fec_operacion;
               rg_gprec.nro_archivo     := k.nro_archivo;
               rg_gprec.monto           := k.monto;
               rg_gprec.cod_error       := pag_cta.FU_OBT_COD_ERROR;
               rg_gprec.msj_error       := pag_cta.FU_OBT_MSJ_ERROR;
               rg_gprec.observacion     := 'En Operación de Débito.';
               rg_gprec.nro_factura     := k.nro_factura;
               rg_gprec.cod_moneda      := k.cod_moneda;
               rg_gprec.tip_cobranza    := k.tip_cobranza;
               PR_INS_LOG(rg_gprec);
             end if;

             if v_procesar = 'S' then
               --Acumulamos el monto debito
                v_mto_debitado := nvl(v_mto_debitado,0) + nvl(k.monto,0);
                v_nro_cta_credito:=k.nro_cta_credito;
                v_cod_ente:=k.cod_ente;
                v_tip_cobranza:=k.tip_cobranza;
                v_fec_operacion:= k.fec_operacion;
                v_nro_archivo:=k.nro_archivo;
                -- Actualiza el estado a N = Procesado.
                 update ge_pag_recaudaciones a
                    set a.estado = 'N',
                        a.nro_documento = v_nro_documento
                  where current of c_rec;
             end if;
           end if;
         end if;
         if v_procesar = 'N' then
           if rg_gprec.cod_error != 222 then -- por hora de corte queda pendiente.
             -- Actualiza el estado a E = Cancelado por Error.
             update ge_pag_recaudaciones a
                set a.estado = 'E',
                    a.nro_documento = v_nro_documento
              where current of c_rec;
           end if;
         end if;
         
         if v_nro_secuencia > 995 then
             v_nro_secuencia := 1;
             v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
         else
           v_nro_secuencia := v_nro_secuencia + 1;
	     end if;
     end loop;
     --Se acredita por el total
      IF nvl(v_mto_debitado,0) > 0 THEN
            pag_cta.PR_SET_NRO_DOCUMENTO3(v_cod_ente);
            --Actualizar el Saldo cta Credito
                    pag_cta.pr_act_operacion(v_nro_cta_credito,
                            v_hora,
                            'C',
                            pag_cta.g_ctas.cod_moneda,
                            v_mto_debitado,
                            v_cod_tra_padre,
                            602,
                            v_nro_documento,           --nro documento
                            null,
                            fug_obt_ofi_usuario(user), --cod_ofi_origen
                            v_cod_mod_cre,             --cod_mod_padre
                            v_cod_mad_cre,             --cod_mad_padre
                            null,                      --cod_tasa
                            null,                      --val_tasa
                            substr('CRÉDITO POR '||fue_obt_des_refcodes('TIP_COB_RECAUDACION', v_tip_cobranza),1,99) ,
                            'S',                       --emi_aviso
                            v_nro_secuencia,
                            v_fec_actual);
                    IF pag_cta.fu_obt_cod_error() <> 0 THEN
                         v_procesar := 'N';
                         rg_gprec.cod_ente        := v_cod_ente;
                         rg_gprec.nro_cta_debito  := null;
                         rg_gprec.nro_cta_credito := v_nro_cta_credito;
                         rg_gprec.fec_operacion   := v_fec_operacion;
                         rg_gprec.nro_archivo     := v_nro_archivo;
                         rg_gprec.monto           := null;
                         rg_gprec.cod_error       := pag_cta.FU_OBT_COD_ERROR;
                         rg_gprec.msj_error       := pag_cta.FU_OBT_MSJ_ERROR;
                         rg_gprec.observacion     := 'En Operación de Crédito por total.';
                         rg_gprec.tip_cobranza    := v_cod_tip_cobranza;
                         pr_ins_log(rg_gprec);
                    END IF;
      END IF;

       -- FMM 25/03/2014 se quito el envio de mail por error y envio de mail al titular de credito
       --se enviaran desde el procedimiento PAG_REC.PR_SRC_ATTACH_XLS
       -- limpiar la variable global
       pag_cta.PR_SET_NRO_DOCUMENTO3(NULL);
    end loop;
     --Si recibio el ente vino del HB por lo que se le envia el cod_ente al proceso
     --Sino recibio es por proceso independiente, en el envio agrupara y enviara los mails
     PAG_REC.PR_SRC_ATTACH_XLS(p_cod_ente);
   END;

PROCEDURE PR_ENV_MAI_COBROS
   IS

   v_fec_actual       date default pag_cal.fu_obt_fec_actual(1);
   v_fec_anterior     date default pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.fu_obt_fec_actual(1),7);
   v_cod_ente         ge_entes.cod_ente%type;
   v_cod_per_ente     ge_cta_clientes.cod_persona%type;
   v_nom_ente         ge_entes.descripcion%type;
   v_dir_mail_ente    ba_personas.dir_correo%type;
   v_cod_per_debito   ge_cta_clientes.cod_persona%type;
   v_nom_cli_debito   ba_personas.nom_completo%type;
   v_inf_rei_cob      varchar2(1) default 'N';

   -- Variables para mail
   v_conn     utl_smtp.connection;
   v_asunto   VARCHAR2(2000);
   v_mje_mail LONG;

   v_hini_mail        ge_ra_log_mail.hor_inicio%type;
   v_hfin_mail        ge_ra_log_mail.hor_fin%type;
   v_det_error        ge_ra_log_mail.det_error%type;

  --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
  V_DETALLE  LONG := '';
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  V_CABECERA LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P');
  --

    CURSOR c_cob_1 is
      --Para envio en Lote
      select distinct(to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1)))) cod_ente,a.cod_moneda
       from ge_mov_pen_cobranzas a
         where a.fec_cobro = v_fec_actual
            and a.estado = 'P'
            and nvl(a.cierre,'N')='S';
             --and a.concepto like '%Cobranza de Seguros.%';


   CURSOR c_cob(p_cod_ente in number, p_cod_moneda in varchar) is
      --Para envio de a uno
      select a.*
       from ge_mov_pen_cobranzas a
         where a.fec_cobro = v_fec_actual
            and a.estado = 'P'
            and nvl(a.cierre,'N')='S'
            --and a.concepto like '%Cobranza de Seguros.%'
            and a.cod_moneda= p_cod_moneda
            and to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1)))= p_cod_ente
      order by a.cod_moneda,a.nro_cuenta;

BEGIN

for c in c_cob_1 loop
     v_cod_ente:=null;
     v_inf_rei_cob:=null;
     v_cod_ente := c.cod_ente;
     v_inf_rei_cob:= nvl(fug_obt_parentes(v_cod_ente, 'INF_REI_COB_SR'),'N');

     if v_inf_rei_cob = 'I' THEN
            --Cobranzas Individuales
            for k in c_cob(v_cod_ente,c.cod_moneda) loop
                   -- Envio de mail al titular de cta debito.
                   v_nom_ente        := fue_obt_nom_ente(v_cod_ente);
                   v_cod_per_ente    := fue_obt_per_ente(v_cod_ente);-- fug_obt_cli_principal(k.nro_cuenta);
                   v_dir_mail_ente   := fug_obt_dir_mail_per(v_cod_per_ente);
                   v_cod_per_debito  := fug_obt_cli_principal(k.nro_cuenta);
                   v_nom_cli_debito  := fue_obt_nom_persona(v_cod_per_debito);
                   BEGIN
                      if v_dir_mail_ente is not null  and fug_ind_produccion = 'S' then
                         --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
                         V_DETALLE :=   '<br><br>
                                          Estimado ' ||v_nom_ente|| ' :
                                         <br><br>
                                          Le informamos que se realizó el cobro por el servicio de recaudaciones y cobranzas
                                          del cliente '||v_nom_cli_debito||'.
                                          <br><br>
                                          Fecha Cobro: '|| to_char(v_fec_actual,'DD/MM/YYYY') ||
                                          '<br>
                                          Hora Cobro: ' || to_char(k.fec_modificacion,'hh24:mi:ss') ||
                                          '<br>
                                          Cuenta de débito: ' || k.nro_cuenta ||
                                          '<br>
                                          Monto: ' || k.monto ||'.
                                          <br>
                                          Moneda: ' || k.cod_moneda ||'.
                                          <br>
                                          Fecha de Recepción de Planilla: ' || k.fecha ||'.
                                          <br>
                                          Referencia: ' || k.observacion ||'.
                                          <br>
                                          Concepto Cobro: Cobranza de Seguros.
                                          <br>
                                          Atentamente.
                                          <br><br>
                                          <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||' </b></i></p>
                                         <br><br> ';

                        --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
                        v_asunto   := 'Recaudaciones y Cobranzas';
                        v_mje_mail := V_CABECERA || chr(10) || chr(10) || chr(10) || V_DETALLE ||
                                      chr(10) || chr(10) || chr(10) || V_FIN|| chr(10) ||V_PIE;
                        v_hini_mail    := to_char(sysdate,'hh24:mi:ss');
                        v_hfin_mail    := to_char(sysdate,'hh24:mi:ss');
                        v_det_error    := null;
                          begin

                            v_conn     := it_mail.begin_mail(c_dir_mail,
                                                             v_dir_mail_ente,
                                                             v_asunto,
                                                             IT_MAIL.MULTIPART_MIME_TYPE);

                            it_mail.attach_text(v_conn, v_mje_mail, 'text/html');


                            it_mail.end_mail(v_conn);
                          EXCEPTION
                              when utl_smtp.transient_error or utl_smtp.permanent_error then
                                  begin
                                    utl_smtp.quit(v_conn);
                                  exception
                                  when utl_smtp.transient_error or utl_smtp.permanent_error then
                                    v_det_error := substr(sqlerrm,1,4000);
                                  end;
                                  v_det_error := substr(sqlerrm,1,4000);
                          END;

                          -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
                          IF v_det_error is not null THEN
                              INSERT INTO ge_ra_log_mail
                               (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                              VALUES
                               (SYSDATE,'Error' , c_dir_mail, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
                              COMMIT;
                              v_det_error    := null;
                          END IF;

                    end if;

                   EXCEPTION
                     when others then
                       v_det_error:=sqlerrm;
                       INSERT INTO ge_ra_log_mail
                               (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                              VALUES
                               (SYSDATE,'Error Ma.Ind.' , c_dir_mail, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
                              COMMIT;
                   END;
              end loop;
    else
       --Para cobranzas agrupadas
           BEGIN
            LP_ENV_MAIL_CIE(c.cod_ente, c.cod_moneda);

           EXCEPTION
             when others then
               v_det_error:=sqlerrm;
                INSERT INTO ge_ra_log_mail
                  (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                  VALUES
                  (SYSDATE,'Error Env.mail.Agru' , c_dir_mail, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
                  COMMIT;



           END;
         end if;

end loop;

END;
PROCEDURE PR_SRC_ATTACH_XLS_CIE(p_cod_ente IN ge_entes.cod_ente%TYPE DEFAULT NULL) IS

  v_fec_actual       date default pag_cal.fu_obt_fec_actual(1);
  v_fec_anterior     date default pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.fu_obt_fec_actual(1),7);
  v_cod_per_debito  ge_cta_clientes.cod_persona%type;
  v_cod_per_credito ge_cta_clientes.cod_persona%type;
  v_nom_ente        ge_entes.descripcion%type;
  v_dir_mail_deb    varchar2(300);--ba_personas.dir_correo%type;
  v_dir_mail_cre    varchar2(300);--ba_personas.dir_correo%type;
  v_nom_cli_debito  ba_personas.nom_completo%type;

  v_texto         varchar2(1000);
  v_texto_detalle clob;
  v_texto_detalle2 clob;
  v_adjunto       clob;
  v_adjunto_error clob;
  v_cabecera      clob;
  v_nom_adj varchar2(500);
  v_total_procesado number ;
  v_total_error number ;
  v_nro_registro number(20);

  v_tot_procesado varchar2(100);
  v_tot_error varchar2(100);

  -- Variables para mail
  v_conn     utl_smtp.connection;
  v_asunto   VARCHAR2(2000);
  v_mje_mail LONG;
  v_db_name  VARCHAR2(20);

  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;
  --
  v_can_normal      number(10):=0;
  v_can_error       number(10):=0;
  v_pie_normal      varchar2(30000);
  v_pie_error       varchar2(30000);
  v_nro_cta_credito varchar2(50);
  v_nro_cta_debito  varchar2(50);
  v_nro_archivo     varchar2(10);
  v_nro_factura     varchar2(200);
  v_tip_cobranza    varchar2(10);
  v_insertar        varchar2(1):='N';
  v_cod_ent_mov_pen varchar2(30);

  --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  v_membrete LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P',c_dir_mail);
  --

  CURSOR g_ente is
     --solo se cobrara en el cierre de ITGF
      select distinct b.cod_ente,b.cod_moneda,b.nro_archivo
       from ge_mov_pen_cobranzas a,ge_pag_recaudaciones b
      where (trunc(a.fec_cobro) = trunc(v_fec_actual))
        and a.estado = 'P'
        and a.concepto like '%Cobranza de Seguros.%'
        and nvl(a.cierre,'N')='S'
        and trunc(a.fecha)=trunc(b.fec_operacion)
        and (to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))))= b.cod_ente
        and b.cod_ente=p_cod_ente
        and a.cod_moneda=b.cod_moneda;

  CURSOR c_rec(v_ente ge_pag_recaudaciones.cod_ente%TYPE,
     v_cod_moneda ge_pag_recaudaciones.cod_moneda%TYPE,
     v_nro_archivo ge_pag_recaudaciones.nro_archivo%TYPE
     ) is
    select a.*
       from ge_mov_pen_cobranzas a
      where (trunc(a.fec_cobro) = trunc(v_fec_actual))
        and a.estado = 'P'
        and a.concepto like '%Cobranza de Seguros.%'
        and nvl(a.cierre,'N')='S'
        and (to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))))= p_cod_ente
        and a.cod_moneda= v_cod_moneda;
  CURSOR g_datos is
    SELECT A.* FROM GE_ENV_PAG_RECAUDACIONES_TMP A
     where a.tipo=v_tip_cobranza
        ORDER BY A.CTA_CREDITO;

begin
  select upper(sys_context('USERENV', 'DB_NAME'))
    into v_db_name
    from dual;
  begin
    -- Envio de mail al titular de cta credito.
    for j in g_ente loop
      delete from ge_env_pag_recaudaciones_tmp;
      --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
       v_texto := '<br><br>
                   <br><br>
                     Estimado Cliente:
                   <br><br>
                     Le informamos que se realizó el proceso de servicios de recaudaciones y cobranzas correspondiente a la fecha ' ||
                             to_char(v_fec_actual, 'DD/MM/YYYY') || ',' || ' en el cual se realizaron las operaciones detalladas en el archivo adjunto.
                   <br><br>
                     Atentamente.
                   <br><br>
                   <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                   <br><br>
                   <br><br>';


         v_cabecera := 'Cliente' || chr(9) || 'Fecha' || chr(9) || 'Nro. Archivo' ||
                    chr(9) || 'Cuenta de débito' || chr(9) ||
                    'Cuenta de crédito' || chr(9) || 'Monto' || chr(9) ||
                    'Moneda' || chr(9) || 'Número de Documento' || chr(9)||'Concepto'||chr(10);

      v_texto_detalle   := null;
      v_texto_detalle2  := null;
      v_adjunto         := null;
      v_adjunto_error   := null;
      v_total_procesado := 0;
      v_tot_procesado   := null;
      v_tot_error       := null;
      v_det_error       := null;
      v_hini_mail       := to_char(sysdate,'hh24:mi:ss');
      v_can_normal      :=0;
      v_can_error       :=0;
      BEGIN
        for k in c_rec(j.cod_ente,j.cod_moneda,j.nro_archivo) loop
          v_insertar:='N';
          --Buscamos los datos de las recaudaciones
          v_nro_registro:= null;
          v_cod_ent_mov_pen := null;
          v_nro_cta_credito:= null;
          v_nro_cta_debito:= null;
          v_nro_archivo:= null;
          v_nro_factura:= null;
          v_tip_cobranza:= null;
          v_nom_ente        := null;
          v_cod_per_debito  := null;
          v_cod_per_credito := null;
          v_dir_mail_deb   := null;
          v_dir_mail_cre    := null;
          v_nom_cli_debito := null;

          v_nro_registro:= trim(substr(k.observacion, 1, instr(k.observacion,'-') -1));
          v_cod_ent_mov_pen := to_number(trim(substr(k.concepto, 1, instr(k.concepto,'-') -1)));
          begin
            select a.nro_cta_credito,a.nro_cta_debito,a.nro_archivo,a.nro_factura,a.tip_cobranza,'S'
             into v_nro_cta_credito,v_nro_cta_debito,v_nro_archivo,
                  v_nro_factura,v_tip_cobranza,v_insertar
              from ge_pag_recaudaciones a
                where a.estado='N'
                    and a.cod_ente=j.cod_ente
                    and a.fec_operacion= k.fecha
                    and a.cod_moneda= j.cod_moneda
                    and a.monto= k.monto
                    and a.nro_documento= v_nro_registro
                    and a.nro_archivo= j.nro_archivo;
          exception
             when others then
                 v_insertar:='N';
           end;


          if  nvl(v_insertar,'N') ='S' THEN
                v_nom_ente        := fue_obt_nom_ente(v_cod_ent_mov_pen);
                v_cod_per_debito  := fug_obt_cli_principal(v_nro_cta_debito);
                v_cod_per_credito := fug_obt_cli_principal(v_nro_cta_credito);
                v_dir_mail_deb    := fug_obt_dir_mail_per(v_cod_per_debito);
                v_dir_mail_cre    := fug_obt_parentes(v_cod_ent_mov_pen,'DIR_MAIL_SR');
                v_nom_cli_debito  := fue_obt_nom_persona(v_cod_per_debito);
                v_total_procesado := v_total_procesado + nvl(k.monto, 0);
             insert into ge_env_pag_recaudaciones_tmp(COD_ENTE,CLIENTE,
               FEC_OPERACION,NRO_ARCHIVO,CTA_DEBITO,CTA_CREDITO,MONTO,COD_MONEDA,CONCEPTO,
               OBSERVACION,TIPO,nro_factura,tip_cobranza)
             values(v_cod_ent_mov_pen,v_nom_cli_debito,
                   to_char(k.fecha, 'DD/MM/YYYY'),to_char(j.nro_archivo),v_nro_cta_debito,
                   v_nro_cta_credito, k.monto, k.cod_moneda,v_nro_factura,
                   fue_obt_des_refcodes('TIP_COB_RECAUDACION', v_tip_cobranza),'N',
                   v_nro_factura,v_tip_cobranza);
           end if;
        end loop;

              v_tot_procesado:= v_total_procesado;
              v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                               v_cabecera || chr(10);-- || v_adjunto || chr(10)||
              v_pie_normal:= chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||v_tot_procesado||chr(10);



     EXCEPTION
        when others then
           v_det_error := substr(sqlerrm,1,4000);
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, 'pag_rec_cie.txt','ERROR', 'Proc.Recaud.Envio.Mail', v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
     END;
      --

      if v_dir_mail_cre is not null and fug_ind_produccion = 'S' then
       --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante|
        v_nom_adj := 'BBVA_SRC_' || j.cod_ente || '_' ||
                     to_char(v_fec_actual, 'DDMMYY')|| '_' ||j.cod_moneda;

        v_asunto   := 'Recaudaciones y Cobranzas';
        v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                      chr(10) || chr(10) || chr(10) || V_FIN|| chr(10) || V_PIE;

        v_det_error    := null;
        BEGIN


                    v_tip_cobranza:='N';
                    v_conn     := it_mail.begin_mail(c_dir_mail,
                                                     v_dir_mail_cre,
                                                     v_asunto,
                                                     IT_MAIL.MULTIPART_MIME_TYPE);

                    it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

                    it_mail.begin_attachment(v_conn,
                                             'text/plain',
                                             false,
                                             v_nom_adj || '.xls');

                     v_texto_detalle := chr(10) || CHR(9) || CHR(9) ||
                                       'SERVICIO DE RECAUDACIONES Y COBRANZAS' || CHR(10)||
                                       v_texto_detalle;

                    it_mail.write_text(v_conn, v_texto_detalle);
                    --************Para Grabar Detalle **************************************
                        for w in g_datos loop
                           v_adjunto:=null;
                             v_adjunto :=  W.CLIENTE || '.' || chr(9) ||
                                 W.fec_operacion || chr(9) ||
                                 to_char(W.nro_archivo) || chr(9) ||
                                 W.CTA_DEBITO || chr(9) || W.cta_credito ||
                                 chr(9) || W.monto || chr(9) || W.cod_moneda || '.' ||
                                 chr(9) || W.nro_factura || '.' ||chr(9)||fue_obt_des_refcodes('TIP_COB_RECAUDACION', W.tip_cobranza)|| chr(10);


                            it_mail.write_text(v_conn, v_adjunto);
                         end loop;
                         --************fin de Grabar Detalle **************************************

                     it_mail.write_text(v_conn, v_pie_normal);
                     if nvl(v_can_error,0)=0 then
                         it_mail.end_mail(v_conn);
                     end if;

       EXCEPTION
        when utl_smtp.transient_error or utl_smtp.permanent_error then
            begin
              utl_smtp.quit(v_conn);
            exception
            when utl_smtp.transient_error or utl_smtp.permanent_error then
              null;
            end;
            v_det_error := substr(sqlerrm,1,4000);
       END;

        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_nom_adj, c_dir_mail, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
            v_det_error    := null;
        END IF;
      end if;

    end loop;

  EXCEPTION
    when others then
      null;
  END;
end;

end PAG_REC;
/

