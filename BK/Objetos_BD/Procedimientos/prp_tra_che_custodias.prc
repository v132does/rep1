create or replace procedure it.prp_tra_che_custodias is
  v_fec_actual    date;
  v_hora          varchar2(8);
  v_cod_modulo    ge_cuentas.cod_modulo%type;
  v_cod_modalidad ge_cuentas.cod_modalidad%type;
  v_cod_retencion ge_movimientos.cod_retencion%type;
  v_fec_fin       date;
  r_gmovi         ge_movimientos%rowtype;
  v_nro_secuencia ge_movimientos.nro_secuencia%type;
  v_estado        cc_che_enviados.estado%type;
  v_nro_cuenta    cc_che_enviados.nro_cuenta%type;
  v_cta_referencia        cc_che_enviados.nro_cuenta%type;
  v_cod_oficina   ba_usuarios.cod_oficina%type;
  v_nro_referencia ge_che_custodias.nro_referencia%type;

  cursor che_custodia is
    select 'C' tipo, a.cod_banco,a.nro_cheque,a.cta_libradora,
           a.cod_moneda,a.monto,a.nro_referencia,
           nvl(a.nro_boleta,0) nro_boleta ,a.cod_oficina,a.rowid, a.fec_vencimiento, a.tip_servicio, a.cod_gru_cheque,
           null estado, a.usu_insercion
      from ge_che_custodias a, ge_calendarios b
     where ((a.fec_vencimiento  between (b.fec_anterior + 1) and b.fec_actual
       and (a.estado = 'C')) or (a.estado = 'N' and a.fec_fin_renegociacion between (b.fec_anterior + 1)  and b.fec_actual))
       and b.cod_modulo = 6
       and not exists(select '1'
                        from cp_che_redescuentos x
                       where x.nro_cheque = a.nro_cheque
                         and x.cod_banco = a.cod_banco)
    union
    select 'R' tipo, a.cod_banco,a.nro_cheque,a.cta_libradora,
           a.cod_moneda,a.monto, a.nro_referencia,
           nvl(a.nro_boleta,0),a.cod_oficina,a.rowid, a.fec_vencimiento, a.tip_servicio, a.cod_gru_cheque,
           c.estado, a.usu_insercion
      from ge_che_custodias a, ge_calendarios b, cp_che_redescuentos c
     where ((a.fec_vencimiento  between (b.fec_anterior + 1)  and b.fec_actual
       and (a.estado = 'C')) or (a.estado = 'N' and a.fec_fin_renegociacion between (b.fec_anterior + 1)  and b.fec_actual))
       and b.cod_modulo = 6
       and a.cod_banco = c.cod_banco
       and a.nro_cheque = c.nro_cheque
       and not exists(select 1
                        from cc_che_enviados e
                       where e.cod_banco= a.cod_banco
                         and e.nro_cheque = a.nro_cheque
                         and e.cta_libradora= a.cta_libradora);

begin
  v_fec_actual := pag_cal.fu_obt_fec_actual(6);
  v_hora := to_char(sysdate,'hh24:mi:ss');

  For che in che_custodia loop
    v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);

    begin
        select nro_cuenta
          into v_cta_referencia
          from ge_che_custodias_det
         where cod_banco = che.cod_banco
           and nro_cheque = che.nro_cheque
           and cta_libradora =che.cta_libradora
           and rownum = 1;
    exception
       when no_data_found then
          v_cta_referencia := che.nro_referencia;
    end;
    --Obtener modulo,modalidad de la cuenta
    begin
      select cod_modulo,cod_modalidad
        into v_cod_modulo,v_cod_modalidad
        from ge_cuentas
       where nro_cuenta = che.nro_referencia;
    exception
      when others then
        v_cod_modulo := null;
        v_cod_modalidad := null;
    end;

    --Obtener la oficina de la cuenta en caso de que no tenga cod_oficina
    if che.cod_oficina is null then
       begin
         select b.cod_oficina
           into v_cod_oficina
           from ge_cuentas b
          where b.nro_cuenta = che.nro_referencia;
       exception
          when others then
             v_cod_oficina := 1;
       end;
    end if;

    --Obtener datos de la retencion.
    if (che.tip_servicio = 'C' or che.tipo = 'R') then
       pag_cta.pr_obt_retencion(v_fec_actual,
                                null,
                                6,
                                608,
                                607,
                                che.cod_moneda,
                                v_cod_retencion,
                                v_fec_fin);
    else
       pag_cta.pr_obt_retencion(v_fec_actual,
                                che.nro_referencia,
                                v_cod_modulo,
                                v_cod_modalidad,
                                607,
                                che.cod_moneda,
                                v_cod_retencion,
                                v_fec_fin);
    end if;
    --Insertar cc_che_enviados
    Begin
        if che.tipo = 'R' then
           if che.estado = 'T'then
              v_estado := 'I';
           else
              v_estado := 'R';
           end if;
           v_nro_cuenta := v_cta_referencia;
        else
           v_estado := 'I';
           v_nro_cuenta := nvl(che.nro_referencia,v_cta_referencia);
        end if;
        insert into cc_che_enviados
              (cod_banco, nro_cheque, cta_libradora,
               cod_moneda, monto, nro_cuenta,  estado,
               fecha, nro_boleta, cod_ofi_origen,
               cod_retencion,cod_usuario,hora,fec_final, fec_vencimiento)
          values(che.cod_banco,che.nro_cheque,che.cta_libradora,
                 che.cod_moneda,che.monto,v_nro_cuenta,v_estado,
                 v_fec_actual,nvl(che.nro_referencia,che.cod_gru_cheque), nvl(che.cod_oficina,v_cod_oficina), --Modificar por tipo de implementacion
                 v_cod_retencion,substr(user,1,10),v_hora,v_fec_fin, che.fec_vencimiento);
    EXCEPTION
       when others then
       raise_application_error(-20000,'Ins.cc_che_enviados ||che.cod_banco||'-'||che.nro_cheque||'-'||che.cta_libradora ||'-'||sqlerrm');
    End;

    --No actualizar el estado, cuando es redescuento...
    if che.tipo <> 'R' then
       update ge_che_custodias
          set estado = 'A'
         where rowid = che.rowid;
    end if;

    If fug_obt_tip_implementacion = 2  then
      --Generar movimiento
      v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;

      r_gmovi.cod_modulo      := 4;
      r_gmovi.cod_modalidad   := 43;
      r_gmovi.cod_oficina     := 1;
      r_gmovi.nro_cuenta      := null;
      r_gmovi.cod_moneda      := che.cod_moneda;
      r_gmovi.cod_usuario     := user;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.fec_valor       := v_fec_actual;
      r_gmovi.cod_tra_padre   := 150;
      r_gmovi.cod_mod_padre   := 4;
      r_gmovi.cod_mad_padre   := 43;
      r_gmovi.cod_transaccion := 151;
      r_gmovi.monto           := che.monto;
      r_gmovi.nro_documento   := che.nro_cheque;
      r_gmovi.cod_tasa        := null;
      r_gmovi.val_tasa        := null;
      r_gmovi.cotizacion      := null;
      r_gmovi.cod_ofi_origen  := 1;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.concepto        := 'Transf.Che.Custodia Nro: '||che.nro_cheque;
      -- genero el movimiento por cambio de estado
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
    End if;
  end loop;
exception
  when others then
    raise_application_error(-20000,'Error en proceso para referencia: '||v_nro_referencia);
end PRP_TRA_CHE_CUSTODIAS;
/

