CREATE OR REPLACE PROCEDURE IT.PRG_GEN_EXT_MT970 IS
  /*
  Inserta los datos recibidos en los archivos MT970. 
  Inserta los movimientos a partir de los datos (cabecera y detalle) de los lotes.
  MTOP: Dic/2020
  */

  v_cta_bbva       varchar2(25);
  v_nro_referencia varchar2(35);
  v_nro_secuencia  varchar2(20);
  --v_fec_extracto varchar2(10);
  v_fec_extracto date;
  v_det_60       varchar(100);
  v_det_62       varchar(100);
  v_tip_sal_ini  char(1);
  v_tip_sal_fin  char(1);
  v_tipo         char(1);
  v_moneda       char(3);
  v_sal_fin      number(18);
  v_sal_ini      number(18);
  v_pos_ini      number;
  v_pos_fin      number;
  v_detalle      varchar2(200);
  v_mto_lote     number(18);
  v_nro_lote     varchar2(50);
  v_fec_lote     date;
  v_nro_sec_bcp  number(18);
  v_lugar        varchar2(200);
  v_error        varchar2(2000);
  v_fec_actual   date := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_fecha        date;
  -----
  v_hora                ge_movimientos.hora%type := to_char(sysdate,
                                                            'HH24:MI:SS');
  v_secuencia           ge_movimientos.nro_secuencia%type := 0;
  v_cod_rub_transitorio ge_movimientos.cod_rubro%type := fug_obt_pardinamico('SNP_COD_RUB_MT102');
  rg_movi               ge_movimientos%rowtype;
  ----
  procedure lp_inserta_detalle(p_fecha       in ge_snp_msj_mt970.fec_proceso%type,
                               p_cod_archivo in ge_snp_msj_mt970.cod_mensaje%type,
                               p_error       out varchar2) is
  
    v_cod_entidad          varchar2(100);
    v_cod_swi_solicitante  varchar2(100);
    v_cod_swi_beneficiario varchar2(100);
  
    cursor det_970 is
      select fecha, cod_archivo, tex_linea, t.nro_orden
        from IT.GE_SNP_MSJ_MT970_TMP t
       where fecha = p_fecha
         and cod_archivo = p_cod_archivo
         and procesado = 'N'
         and instr(tex_linea, ':61:') > 0
       order by t.cod_archivo, t.nro_orden;
  
  begin
    for e in det_970 loop
      begin
        --
        v_lugar   := 'Obt.Detalle.Tag:61';
        v_detalle := pao_pmt.fu_obt_val_campo(e.tex_linea, '61');
        --
        v_lugar := 'Obt.CodEntidad.';
        begin
          select tex_linea
            into v_cod_entidad
            from GE_SNP_MSJ_MT970_TMP t
           where t.fecha = e.fecha
             and t.cod_archivo = e.cod_archivo
             and t.nro_orden = e.nro_orden + 1;
        exception
          when others then
            p_error := v_lugar || '-' || sqlerrm;
        end;
      
        if substr(v_detalle, 7, 1) = 'D' then
          v_tipo                 := 'D';
          v_cod_swi_beneficiario := v_cod_entidad;
          v_cod_swi_solicitante  := 'BBVAPYPA'; -- orden de credito a las demas entidades (enviadas)
          --dbms_output.put_line('v_tipo '||v_tipo);
        else
          v_tipo                 := 'C';
          v_cod_swi_solicitante  := v_cod_entidad;
          v_cod_swi_beneficiario := 'BBVAPYPA'; -- las demas entidades nos acreditan (recibidas)
          --dbms_output.put_line('v_tipoC '||v_tipo);
        end if;
        --
        v_lugar    := 'Obt.Mto.Lote';
        v_mto_lote := substr(v_detalle,
                             instr(v_detalle, v_tipo) + 1,
                             instr(v_detalle, ',') -
                             (instr(v_detalle, v_tipo) + 1));
        --dbms_output.put_line('v_mto_lote '||v_mto_lote);
        --
        v_lugar    := 'Obt.Nro.Lote';
        v_nro_lote := substr(v_detalle,
                             instr(v_detalle, 'S'),
                             (instr(v_detalle, '/') - instr(v_detalle, 'S')));
        v_nro_lote := substr(v_nro_lote, 5, length(v_nro_lote) - 3);
        --
        v_lugar    := 'Obt.Fec.Lote';
        v_fec_lote := to_date(substr(v_detalle, 1, 6), 'yy/mm/dd');
        --dbms_output.put_line('v_fec_lote '||v_fec_lote);
        --
        v_lugar       := 'Obt.Nro.Sec.Lote';
        v_nro_sec_bcp := substr(v_detalle,
                                instr(v_detalle, '//', 1) + 2,
                                length(v_detalle) -
                                instr(v_detalle, '//', 1));
        --dbms_output.put_line('v_nro_sec_bcp '||v_nro_sec_bcp);
      
        --
        v_lugar := 'Ins.ge_snp_msj_mt970_det';
        INSERT into GE_SNP_MSJ_MT970_DET
          (cod_mensaje,
           fec_extracto,
           tip_movimiento,
           monto,
           nro_lote,
           fec_lote,
           nro_identificador,
           lin_extracto,
           cod_swi_pte_solicitante,
           cod_swi_pte_beneficiario)
        VALUES
          (e.cod_archivo,
           v_fec_extracto,
           v_tipo,
           v_mto_lote,
           v_nro_lote,
           v_fec_lote,
           v_nro_sec_bcp,
           v_detalle,
           v_cod_swi_solicitante,
           v_cod_swi_beneficiario);
        --
        v_tipo                 := null;
        v_mto_lote             := null;
        v_nro_lote             := null;
        v_nro_sec_bcp          := null;
        v_cod_entidad          := null;
        v_cod_swi_solicitante  := null;
        v_cod_swi_beneficiario := null;
        v_detalle              := null;
        p_error                := 'OK';
        --
      exception
        when others then
          p_error := v_lugar || '-' || sqlerrm;
      end;
    end loop;
  exception
    when others then
      p_error := 'Error.' || sqlerrm;
      --dbms_output.put_line('Error en lp_insertar_detalle '||p_error);
  end lp_inserta_detalle;
  ----------------------------------------------------------------------------------------------------

  ----------------------------------------------------------------------------------------------------
  procedure lp_inserta_cabecera is
    cursor cab_970 is
      select fecha, cod_archivo, tex_linea, t.nro_orden
        from IT.GE_SNP_MSJ_MT970_TMP t
       where fecha >= trunc(sysdate) - 6 -- va intentar generar el ext no procesado de los ult 6 dias
         and procesado = 'N'
         and instr(tex_linea, ':61:') = 0
      --and nro_orden > 1
       order by t.cod_archivo, t.nro_orden;
  
    v_tip_corte varchar2(10);
  begin
    for e in cab_970 loop
      prg_cre_savepoint('mt970');
      --
      --
      begin
        if e.nro_orden = 1 then
          if instr(e.tex_linea, 'FIRST') > 0 then
            v_tip_corte := 'FIRST';
          end if;
        
          if instr(e.tex_linea, 'SECOND') > 0 then
            v_tip_corte := 'SECOND';
          end if;
        
          if instr(e.tex_linea, 'FINAL') > 0 then
            v_tip_corte := 'FINAL';
          end if;
        end if;
        --
        if instr(e.tex_linea, ':20:') > 0 then
          v_lugar          := 'Obt.NroReferencia';
          v_nro_referencia := replace(pao_pmt.fu_obt_val_campo(e.tex_linea,
                                                               '20'),
                                      '/970');
          --dbms_output.put_line('Extracto '||v_nro_referencia);
        end if;
      
        if instr(e.tex_linea, ':25:') > 0 then
          v_lugar    := 'Obt.NroCuenta';
          v_cta_bbva := pao_pmt.fu_obt_val_campo(e.tex_linea, '25');
          --dbms_output.put_line('Cuenta '||v_cta_bbva);
        end if;
      
        if instr(e.tex_linea, ':28C:') > 0 then
          v_lugar         := 'Obt.NroSecuencia';
          v_nro_secuencia := pao_pmt.fu_obt_val_campo(e.tex_linea, '28C');
          --dbms_output.put_line('Secuencia '||v_nro_secuencia);
        end if;
      
        --:60F:C201124PYG0,
        --:60M:D201124PYG1009325771,
      
        if instr(e.tex_linea, ':60F:') > 0 then
          -- obtengo el string del tag:60F
          v_det_60 := pao_pmt.fu_obt_val_campo(e.tex_linea, '60F');
          --
          v_lugar        := 'Obt.FecExtracto.60F';
          v_fec_extracto := to_date(substr(v_det_60, 2, 6), 'yy/mm/dd');
          --
          v_lugar       := 'Obt.TipMov.Sal.Inicial.60F';
          v_tip_sal_ini := substr(v_det_60, 1, 1);
          --
          v_pos_ini := instr(v_det_60, 'PYG') + 3;
          v_pos_fin := instr(v_det_60, ',');
          v_lugar   := 'Obt.SalInicial.Tag60F';
        
          v_sal_ini := substr(v_det_60, v_pos_ini, (v_pos_fin - v_pos_ini));
          --
          --dbms_output.put_line('Fec Extracto '||v_fec_extracto);
        end if;
      
        if instr(e.tex_linea, ':60M:') > 0 then
          -- obtengo el string del tag:60M
          v_det_60 := pao_pmt.fu_obt_val_campo(e.tex_linea, '60M');
          --
          v_lugar        := 'Obt.FecExtracto.60M';
          v_fec_extracto := to_date(substr(v_det_60, 2, 6), 'yy/mm/dd');
          --
          v_lugar       := 'Obt.TipMov.Sal.Inicial.60M';
          v_tip_sal_ini := substr(v_det_60, 1, 1);
          --
          v_pos_ini := instr(v_det_60, 'PYG') + 3;
          v_pos_fin := instr(v_det_60, ',');
          v_lugar   := 'Obt.SalInicial.Tag60M';
        
          v_sal_ini := substr(v_det_60, v_pos_ini, (v_pos_fin - v_pos_ini));
          --
        
          --dbms_output.put_line('Fec Extracto '||v_fec_extracto);
        end if;
        --
      
        --
        if instr(e.tex_linea, ':62M:') > 0 then
          --:62M:D201124PYG1009325771,  --86093491
        
          v_lugar  := 'Obt.LineaSaldo62M';
          v_det_62 := pao_pmt.fu_obt_val_campo(e.tex_linea, '62M');
          --dbms_output.put_line('v_sal_aux '||v_sal_aux);
          --
          v_lugar       := 'Obt.TipMov.SalFin.60M';
          v_tip_sal_fin := substr(v_det_62, 1, 1);
          --
          v_lugar  := 'Obt.Mon.62M';
          v_moneda := substr(v_det_62, instr(v_det_62, 'PYG'), 3);
          --dbms_output.put_line('Moneda '||v_moneda);
          --
          --
          v_pos_ini := instr(v_det_62, 'PYG') + 3;
          v_pos_fin := instr(v_det_62, ',');
          v_lugar   := 'Obt.Sal.Final.62M';
        
          v_sal_fin := substr(v_det_62, v_pos_ini, (v_pos_fin - v_pos_ini));
        
          --dbms_output.put_line('Saldo '||v_saldo);
          --
        end if;
      
        --
        if instr(e.tex_linea, ':62F:') > 0 then
          v_lugar := 'Obt.LineaSaldo';
          --
          v_det_62 := pao_pmt.fu_obt_val_campo(e.tex_linea, '62F');
          --D201124PYG686093491,  --86093491
          --
          v_lugar       := 'Obt.TipMov.Sal.Fin.62F';
          v_tip_sal_fin := substr(v_det_62, 1, 1);
          --dbms_output.put_line('Tipo '||v_tipo);
          --
          v_lugar  := 'Obt.Mon.62F';
          v_moneda := substr(v_det_62, instr(v_det_62, 'PYG'), 3);
          --dbms_output.put_line('Moneda '||v_moneda);
          --
          v_pos_ini := instr(v_det_62, 'PYG') + 3;
          v_pos_fin := instr(v_det_62, ',');
          v_lugar   := 'Obt.Sal.Fin.62F';
        
          v_sal_fin := substr(v_det_62, v_pos_ini, (v_pos_fin - v_pos_ini));
        
          --dbms_output.put_line('Saldo '||v_saldo);
          --
        end if;
        --
        --
        if v_fec_extracto is not null and v_nro_referencia is not null and
           v_nro_secuencia is not null and v_cta_bbva is not null and
           v_moneda is not null and v_tip_sal_fin is not null and
           v_sal_fin is not null then
          begin
            --
            v_lugar := 'Ins.GE_SNP_MSJ_MT970';
            insert into GE_SNP_MSJ_MT970
              (FEC_PROCESO,
               COD_MENSAJE,
               FEC_EXTRACTO,
               NRO_REFERENCIA,
               NRO_SECUENCIA,
               NRO_CTA_BBVA,
               MONEDA,
               TIP_MOV_INICIAL,
               SAL_INICIAL,
               TIP_MOV_FINAL,
               SAL_FINAL,
               DES_CORTE)
            values
              (e.fecha,
               e.cod_archivo,
               v_fec_extracto,
               v_nro_referencia,
               v_nro_secuencia,
               v_cta_bbva,
               v_moneda,
               v_tip_sal_ini,
               v_sal_ini,
               v_tip_sal_fin,
               v_sal_fin,
               v_tip_corte);
            --
            v_lugar := 'Ins.DetalleMT970';
            lp_inserta_detalle(e.fecha, e.cod_archivo, v_error);
          
            --
            if nvl(v_error, 'OK') = 'OK' then
              v_lugar := 'Upd.GE_SNP_MSJ_MT970_TMP.Ok';
              update GE_SNP_MSJ_MT970_TMP
                 set procesado = 'S'
               where fecha = e.fecha
                 and cod_archivo = e.cod_archivo
                 and procesado = 'N';
              commit;
            else
              v_lugar := 'Upd.GE_SNP_MSJ_MT970_TMP.Err';
              prg_rol_savepoint('mt970');
              update GE_SNP_MSJ_MT970_TMP
                 set procesado = 'E', det_error = v_error
               where fecha = e.fecha
                 and cod_archivo = e.cod_archivo
                 and procesado = 'N';
              commit;
              --
              prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                           (fug_obt_pardinamico('CAM_MAR_DIR_SAU')||';'||fug_obt_pardinamico('CAM_MAR_DIR_TYC')),
                           '[EXTRACTOS MT970] Error en la generacion ' ||
                           e.cod_archivo,
                           v_error);
              --
            end if;
          exception
            when others then
              v_error := sqlerrm;
              prg_rol_savepoint('mt970');
            
              update ge_snp_msj_mt970_tmp
                 set det_error = substr(v_lugar || '-' || v_error, 1, 2000),
                     procesado = 'E'
               where fecha = e.fecha
                 and cod_archivo = e.cod_archivo;
              commit;
              --
              prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                           (fug_obt_pardinamico('CAM_MAR_DIR_SAU')||';'||fug_obt_pardinamico('CAM_MAR_DIR_TYC')),
                           '[EXTRACTOS MT970] Error en la generacion ' ||
                           e.cod_archivo,
                           v_error);
              --
          
          end;
        
          v_fec_extracto   := null;
          v_nro_referencia := null;
          v_nro_secuencia  := null;
          v_cta_bbva       := null;
          v_tip_sal_fin    := null;
          v_moneda         := null;
          v_sal_fin        := null;
        end if;
      exception
        when others then
          v_error := sqlerrm;
          prg_rol_savepoint('mt970');
          --dbms_output.put_line('v_error '||v_error);
          update ge_snp_msj_mt970_tmp
             set det_error = substr(v_lugar || '-' || v_error, 1, 2000),
                 procesado = 'E'
           where cod_archivo = e.cod_archivo;
          commit;
          --
          prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                       (fug_obt_pardinamico('CAM_MAR_DIR_SAU')||';'||fug_obt_pardinamico('CAM_MAR_DIR_TYC')),
                       '[EXTRACTOS MT970] Error en la generacion ' ||
                       e.cod_archivo,
                       v_error);
          --
      
      end;
    end loop;
  end lp_inserta_cabecera;
  ----
  procedure lp_inserta_movimientos is
  
    cursor detalle is
      select d.*
        from ge_snp_msj_mt970_det d, ge_snp_msj_mt970 c
       where d.cod_mensaje = c.cod_mensaje
         and d.fec_extracto = c.fec_extracto
         and d.ind_movimiento = 'N'
         and c.fec_proceso >= nvl(v_fecha, trunc(sysdate));
  
    cursor cabecera is
      select 'I' tipo, s.*
        from ge_snp_msj_mt970 s
       where fec_proceso >= nvl(v_fecha, trunc(sysdate))
         and s.ind_movimiento = 'N'
         and nvl(s.sal_inicial, 0) > 0
      union
      select 'F', s.*
        from ge_snp_msj_mt970 s
       where s.fec_proceso >= nvl(v_fecha, trunc(sysdate))
         and s.ind_movimiento = 'N'
         and nvl(s.sal_final, 0) > 0;
  
    --
    v_cod_tra_padre ge_snp_transferencias.cod_tra_padre%type;
    --
  begin
    v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
  
    -- valido por si no se hayan generado movimientos del dia anterior
    begin
      select fec_proceso
        into v_fec_extracto
        from ge_snp_msj_mt970
       where ind_movimiento = 'N'
         and fec_proceso = pag_Cal.FU_OBT_FEC_ANT_HAB(v_fec_actual, 1, 1);
    
      v_fecha := v_fec_extracto;
    exception
      when no_data_found then
        v_fecha        := null;
        v_fec_extracto := null;
      when too_many_rows then
        select fec_extracto
          into v_fec_extracto
          from ge_snp_msj_mt970
         where ind_movimiento = 'N'
           and fec_proceso = pag_Cal.FU_OBT_FEC_ANT_HAB(v_fec_actual, 1, 1)
           and rownum = 1;
      
        v_fecha := v_fec_extracto;
      when others then
        v_fecha        := null;
        v_fec_extracto := null;
    end;
  
    for m in detalle loop
      prg_cre_savepoint('detalle');
      begin
        -- obtengo la transaccion padre del lote
        begin
          select cod_tra_padre
            into v_cod_tra_padre
            from ge_snp_transferencias
           where nro_lote = m.nro_lote
             and fec_valor = m.fec_lote
             and rownum = 1;
        exception
          when others then
            v_cod_tra_padre := 303; -- por defecto transf de clientes normales
        end;
        --
        if v_secuencia >= 990 then
          v_secuencia := 0;
          v_hora      := fug_obt_hor_disponible(v_fec_actual,
                                                v_hora,
                                                user,
                                                'N');
        end if;
        --
      
        rg_movi.fecha       := v_fec_actual;
        rg_movi.hora        := v_hora;
        rg_movi.cod_usuario := user;
        --
        v_secuencia := v_secuencia + 1;
        --
        rg_movi.nro_secuencia  := v_secuencia;
        rg_movi.fec_valor      := v_fec_actual;
        rg_movi.monto          := m.monto;
        rg_movi.nro_cuenta     := null;
        rg_movi.cod_moneda     := 'GS';
        rg_movi.cod_oficina    := 31;
        rg_movi.estado         := 'N';
        rg_movi.cod_ofi_origen := 31;
        rg_movi.concepto       := 'Extracto M970-Lote: ' || m.nro_lote;
        rg_movi.cod_rubro      := v_cod_rub_transitorio;
        rg_movi.reversado      := 'N';
        rg_movi.emi_aviso      := 'N';
        rg_movi.cod_tra_padre  := v_cod_tra_padre;
        rg_movi.cod_mod_padre  := 4;
        rg_movi.cod_mad_padre  := 455;
        rg_movi.cod_modulo     := 4;
        rg_movi.cod_modalidad  := 455;
        --
        if FUE_VAL_ES_NUMERICO(m.nro_lote) = 'S' then
          rg_movi.nro_documento := m.nro_lote;
        end if;
        --
        rg_movi.nro_documento2 := m.nro_identificador;
        rg_movi.tip_mov_rubro  := m.tip_movimiento;
      
        rg_movi.referencia := substr(m.nro_lote, 1, 20);
      
        pag_gen.PR_INS_GE_MOVIMIENTO(rg_movi);
      
        update ge_snp_msj_mt970_det
           set ind_movimiento = 'S'
         where fec_extracto = m.fec_extracto
           and cod_mensaje = m.cod_mensaje
           and nro_lote = m.nro_lote
           and nro_identificador = m.nro_identificador;
        --
        rg_movi := null;
        --
      exception
        when others then
          prg_rol_savepoint('detalle');
          raise_application_error(-20001, 'Ins.Mov.Det.MT970:' || sqlerrm);
        
      end;
    end loop;
    -----------------------------------------------------------------------------------------------
    rg_movi     := null;
    v_secuencia := 0;
    v_hora      := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
    -----------------------------------------------------------------------------------------------
    for c in cabecera loop
      prg_cre_savepoint('cabecera');
      begin
        if v_secuencia >= 990 then
          v_secuencia := 0;
          v_hora      := fug_obt_hor_disponible(v_fec_actual,
                                                v_hora,
                                                user,
                                                'N');
        end if;
        --
      
        rg_movi.fecha       := v_fec_actual;
        rg_movi.hora        := v_hora;
        rg_movi.cod_usuario := user;
        --
        v_secuencia := v_secuencia + 1;
        --
        rg_movi.nro_secuencia := v_secuencia;
        rg_movi.fec_valor     := v_fec_actual;
        rg_movi.nro_cuenta    := '3145002660'; --SIPAP - BCP - CTA CTE - GS
        if c.tipo = 'I' then
          rg_movi.monto := c.sal_inicial;
        else
          rg_movi.monto := c.sal_final;
        end if;
        rg_movi.cod_moneda     := 'GS';
        rg_movi.cod_oficina    := 31;
        rg_movi.estado         := 'N';
        rg_movi.cod_ofi_origen := 31;
        rg_movi.concepto       := 'Extracto M970. Ref. ' ||
                                  c.nro_referencia;
        rg_movi.cod_rubro      := '111201051001199'; -- Rubro SIPAP - BCP - GS
        rg_movi.reversado      := 'N';
        rg_movi.emi_aviso      := 'N';
        rg_movi.cod_tra_padre  := 303;
        rg_movi.cod_mod_padre  := 4;
        rg_movi.cod_mad_padre  := 455;
        rg_movi.cod_modulo     := 4;
        rg_movi.cod_modalidad  := 455;
        --
        rg_movi.nro_documento := replace(c.nro_referencia, 'S');
        --
        rg_movi.nro_documento2 := c.cod_mensaje;
        ------------
        if c.tipo = 'I' then
          -- si es el saldo inicial se registra con el signo que viene en el extracto
          rg_movi.tip_mov_rubro := c.tip_mov_inicial;
        else
          -- si es el saldo final, cambiamos el signo. (definicion L.A)
          if c.tip_mov_final = 'D' then
            rg_movi.tip_mov_rubro := 'C';
          else
            rg_movi.tip_mov_rubro := 'D';
          end if;
        end if;
        ------------
        rg_movi.referencia := substr(c.nro_referencia, 1, 20);
      
        pag_gen.PR_INS_GE_MOVIMIENTO(rg_movi);
      
        -- actualizamos por numero de referencia para que cambie el valor a todos los lotes del mismo corte
        update ge_snp_msj_mt970
           set ind_movimiento = 'S'
         where fec_proceso = c.fec_proceso
           and nro_referencia = c.nro_referencia
           and nro_secuencia = c.nro_secuencia
           and des_corte = c.des_corte
           and ind_movimiento = 'N';
        --
        rg_movi := null;
        --
      exception
        when others then
          raise_application_error(-20001,
                                  'Ins.Movim.Ref ' || c.nro_referencia ||
                                  '-Arc.' || c.cod_mensaje || '-' ||
                                  sqlerrm);
      end;
    
    end loop;
    --
  end lp_inserta_movimientos;

  --------------------------------------------------------------------------
  ----
  --------------------------------------------------------------------------

  procedure lp_ins_rch_mt102 is
  
    cursor rch is
      select s.*
        from ge_snp_transferencias s
       where fec_valor = v_fec_actual
         and fec_recepcion is not null
         and cod_msj_swift = 102
         and nro_lote is not null
         and estado = 'R'
         and lower(nvl(concepto, 'x')) not like 'reversión%referencia%'
         and not exists (select 1
                from ge_movimientos m
               where m.nro_documento = s.nro_referencia
                 and m.cod_modalidad = 455);
  
  begin
    v_hora      := to_char(sysdate, 'hh24:mi:ss');
    v_hora      := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
    v_secuencia := 0;
    --
    for r in rch loop
      rg_movi := null;
      if v_secuencia >= 990 then
        v_secuencia := 0;
        v_hora      := fug_obt_hor_disponible(v_fec_actual,
                                              v_hora,
                                              user,
                                              'N');
      end if;
      --
    
      rg_movi.fecha       := v_fec_actual;
      rg_movi.hora        := v_hora;
      rg_movi.cod_usuario := user;
      --
      v_secuencia := v_secuencia + 1;
      --
      rg_movi.nro_secuencia  := v_secuencia;
      rg_movi.fec_valor      := v_fec_actual;
      rg_movi.monto          := r.monto;
      rg_movi.nro_cuenta     := null;
      rg_movi.cod_moneda     := 'GS';
      rg_movi.cod_oficina    := 31;
      rg_movi.estado         := 'N';
      rg_movi.cod_ofi_origen := 31;
      rg_movi.concepto       := 'Reversion Ref. ' || r.nro_sec_lote;
      rg_movi.cod_rubro      := v_cod_rub_transitorio;
      rg_movi.reversado      := 'N';
      rg_movi.emi_aviso      := 'N';
      rg_movi.cod_tra_padre  := r.cod_tra_padre;
      rg_movi.cod_mod_padre  := 4;
      rg_movi.cod_mad_padre  := 455;
      rg_movi.cod_modulo     := 4;
      rg_movi.cod_modalidad  := 455;
      --
      rg_movi.nro_documento := r.nro_referencia;
      --
      rg_movi.tip_mov_rubro := 'C';
      ------------
      rg_movi.referencia := substr(r.nro_sec_lote, 1, 20);
    
      pag_gen.PR_INS_GE_MOVIMIENTO(rg_movi);
      --
      --
      rg_movi.fecha       := v_fec_actual;
      rg_movi.hora        := v_hora;
      rg_movi.cod_usuario := user;
      --
      v_secuencia := v_secuencia + 1;
      --
      rg_movi.nro_secuencia  := v_secuencia;
      rg_movi.fec_valor      := v_fec_actual;
      rg_movi.monto          := r.monto;
      rg_movi.nro_cuenta     := null;
      rg_movi.cod_moneda     := 'GS';
      rg_movi.cod_oficina    := 31;
      rg_movi.estado         := 'N';
      rg_movi.cod_ofi_origen := 31;
      rg_movi.concepto       := 'Reversion Ref. ' || r.nro_sec_lote;
      rg_movi.cod_rubro      := v_cod_rub_transitorio;
      rg_movi.reversado      := 'N';
      rg_movi.emi_aviso      := 'N';
      rg_movi.cod_tra_padre  := r.cod_tra_padre;
      rg_movi.cod_mod_padre  := 4;
      rg_movi.cod_mad_padre  := 455;
      rg_movi.cod_modulo     := 4;
      rg_movi.cod_modalidad  := 455;
      --
      rg_movi.nro_documento := r.nro_referencia;
      --
      rg_movi.tip_mov_rubro := 'D';
      ------------
      rg_movi.referencia := substr(r.nro_sec_lote, 1, 20);
    
      pag_gen.PR_INS_GE_MOVIMIENTO(rg_movi);
    end loop;
  exception
    when others then
      v_error := 'Ins. Movimiento de Rechazados ' || sqlerrm;
      prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                   (fug_obt_pardinamico('CAM_MAR_DIR_SAU')||';'||fug_obt_pardinamico('CAM_MAR_DIR_TYC')),
                   '[EXTRACTOS MT970] Movim.RCH',
                   v_error);
      raise_application_error(-20003, v_error);
  end lp_ins_rch_mt102;

  --------------------
  --  I N I C I O   --
  --------------------
begin
  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
    pae_cnf.G_PROGRAMA   := 'GPPROFIN';
  END;
  -- inserta las tablas ge_snp_msj_mt970 y  ge_snp_msj_mt970_det
  lp_inserta_cabecera;

  -- inserta movimientos
  lp_inserta_movimientos;

  -- inserta movimientos sipap rechazados del dia.
  lp_ins_rch_mt102;
end;
/

