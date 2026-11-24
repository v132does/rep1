CREATE OR REPLACE PROCEDURE IT.PRG_GEN_COM_ATM
is

  r_gmovi     ge_movimientos%rowtype;
  v_decimales number;
  --v_fecha     ge_par_dinamicos.fec_modificacion%type;
  v_cod_ent_financiera cc_cta_bancarias.cod_ente%type;

  -- Impuesto
  v_val_cargo number;
  v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
  v_cod_tas_impuesto number;
  v_val_tas_impuesto number;
  v_val_impuesto number;

  -- Cursor principal
  cursor pag is
    select cod_banco, nom_banco, referencia,
           round(to_number(ltrim(rtrim(replace(mto_recibido,'.',''))) )) mto_recibido,
           round(to_number(ltrim(rtrim(replace(mto_pagado,'.',''))) )) mto_pagado
      from ge_com_atm_tmp t
     order by cod_banco, mto_recibido, mto_pagado;
begin
  -- Acepta en esta sesión como separador de decimales la coma.
  pre_cam_for_numerico(',.');
  --
  v_decimales := fue_dec_mon_local;
  r_gmovi.fecha := pae_cnf.fu_obt_fec_actual(1);
  r_gmovi.hora := to_char(sysdate,'hh24:mi:ss');
  r_gmovi.cod_moneda := pag_gen.fu_obt_mon_local;
  r_gmovi.cod_ofi_origen := fug_obt_ofi_usuario(user);
  --
  r_gmovi.cod_modulo := 4;
  --r_gmovi.cod_modalidad := 42;
  r_gmovi.nro_secuencia := 0;
  --El archivo de importación trae los valores en guaraníes
  --r_gmovi.cotizacion := nvl(fug_obt_pardinamico('COT_COM_ATM',null,null,null,null),0);

  begin
    delete from ge_com_atm_tmp
     where cod_banco is null;
  end;

  --trae el importe en guaranies
  /*begin
    select trunc(fec_modificacion)
      into v_fecha
      from ge_par_dinamicos
     where parametro = 'COT_COM_ATM'
       and cod_modulo is null
       and cod_modalidad is null
       and cod_sub_modalidad is null
       and cod_oficina is null
       and cod_moneda is null;
  exception
    when no_data_found then
      v_fecha := trunc(sysdate)-1;
    when others then
      raise_application_error(-20000,'Error al buscar el parámetro. '||sqlerrm);
  end;

  if v_fecha <> trunc(sysdate) then
    raise_application_error(-20000,'Debe ingresar la Cotización correspondiente a la Fecha.');
  end if;*/
  --
  for p in pag loop
    --
    begin
      --wa:11/08/2014 se ajusta para modalidad 49
      select b.nro_cuenta,b.cod_modalidad
        into r_gmovi.nro_cuenta,r_gmovi.cod_modalidad
        from cc_cta_bancarias b,
             ge_cta_clientes c
       where b.nro_cuenta = c.nro_cuenta
         and c.relacion = 'P'
         and ((b.cod_ente=p.cod_banco and b.cod_modalidad=49) or
             (b.cod_banco=p.cod_banco and b.cod_modalidad=42))
         and b.cod_moneda = r_gmovi.cod_moneda;
    exception
      when others then
        r_gmovi.nro_cuenta := null;
    end;

    -- si no es un banco es una financiera
    if r_gmovi.nro_cuenta is null then
       begin
         select e.cod_ente
           into v_cod_ent_financiera
           from ge_par_entes pe, ge_entes e
          where pe.parametro = 'COD_ENT_FINANCIERA'
            and pe.cod_ente = e.cod_ente
            and pe.val_parametro=p.cod_banco
            and e.tipo = 'FI';
       exception
          when no_data_found then
            v_cod_ent_financiera:=null;
          when others then
            v_cod_ent_financiera:=null;
       end;
       begin
        --wa:11/08/2014 se ajusta para modalidad 49
        select b.nro_cuenta,b.cod_modalidad
          into r_gmovi.nro_cuenta,r_gmovi.cod_modalidad
          from cc_cta_bancarias b,
               ge_cta_clientes c
         where b.nro_cuenta = c.nro_cuenta
           and c.relacion = 'P'
           and b.cod_ente= v_cod_ent_financiera and b.cod_modalidad=49
           and b.cod_moneda = r_gmovi.cod_moneda;
       exception
        when others then
          r_gmovi.nro_cuenta := null;
       end;
    end if;
    --
    if r_gmovi.nro_cuenta is not null then
      -- Monto a Pagar
      -- CNFRITGF-1 Recibos ITGF, se comenta la generación de pago de comisión de Atm, debido a que se realiza por SIPAP
      /*r_gmovi.monto := p.mto_pagado; --round(r_gmovi.cotizacion * nvl(p.mto_pagado,0),v_decimales);
      r_gmovi.cod_transaccion := 7602;
      pag_cta.g_cod_error := 0;
      --
      if r_gmovi.monto > 0 then
        pag_cta.pr_act_operacion(r_gmovi.nro_cuenta,
                                 r_gmovi.hora,
                                 'C', -- Crédito a la cuenta
                                 r_gmovi.cod_moneda,
                                 r_gmovi.monto,
                                 r_gmovi.cod_transaccion, -- trans. padre
                                 r_gmovi.cod_transaccion, -- trans. hijo
                                 null, -- nro_documento
                                 null, -- cotizacion
                                 r_gmovi.cod_ofi_origen, -- Oficina origen
                                 r_gmovi.cod_modulo,
                                 r_gmovi.cod_modalidad,
                                 null, -- tasa
                                 null, -- valor de tasa
                                 substr('Cre. Comisión uso ATM - Mto '||p.mto_pagado||' Cotización '||r_gmovi.cotizacion||' Ref: '||p.referencia,1,100), -- concepto
                                 'N', -- emitir aviso
                                 r_gmovi.nro_secuencia, -- nro de secuencia
                                 r_gmovi.fecha);
        --Obtiene valores del impuesto.
        v_val_cargo := 0;
        v_cod_tra_impuesto := 0;
        v_cod_tas_impuesto := 0;
        v_val_tas_impuesto := 0;
        v_val_impuesto := 0;
        --
        prg_obt_car_impuesto(r_gmovi.cod_ofi_origen,
                             r_gmovi.nro_cuenta,
                             r_gmovi.cod_moneda,
                             r_gmovi.cod_modulo,
                             r_gmovi.cod_modalidad,
                             r_gmovi.cod_transaccion,
                             v_val_cargo,
                             v_cod_tra_impuesto,
                             v_cod_tas_impuesto,
                             v_val_tas_impuesto,
                             v_val_impuesto);
        --
        v_val_impuesto := round(nvl(r_gmovi.monto,0) * (v_val_tas_impuesto/100),v_decimales);
        --
        if v_val_impuesto > 0 and pag_cta.g_cod_error = 0 then
          -- Impuesto
          pag_cta.pr_act_operacion(r_gmovi.nro_cuenta,
                                   r_gmovi.hora,
                                   'C', -- Crédito a la cuenta del banco país
                                   r_gmovi.cod_moneda,
                                   v_val_impuesto,
                                   r_gmovi.cod_transaccion, -- trans. padre
                                   v_cod_tra_impuesto, -- trans. hijo
                                   null, -- nro_documento
                                   null, -- cotizacion
                                   r_gmovi.cod_ofi_origen, -- Oficina origen
                                   r_gmovi.cod_modulo,
                                   r_gmovi.cod_modalidad,
                                   v_cod_tas_impuesto, -- tasa
                                   v_val_tas_impuesto, -- valor de tasa
                                   'Cre. IVA s/Comisión por uso de ATM', --concepto
                                   'N', -- emitir aviso
                                   r_gmovi.nro_secuencia, -- nro de secuencia
                                   r_gmovi.fecha);
          if pag_cta.g_cod_error <> 0 then
            raise_application_error( -20000,pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error() );
          end if;
        else
          raise_application_error( -20000,pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error() );
        end if;
      end if;*/
      -- Monto Recibido
      r_gmovi.monto := p.mto_recibido;--round(r_gmovi.cotizacion * nvl(p.mto_recibido,0),v_decimales);
      r_gmovi.cod_transaccion := 7503;
      pag_cta.g_cod_error := 0;
      --
      if r_gmovi.monto > 0 then
        pag_cta.pr_act_operacion(r_gmovi.nro_cuenta,
                                 r_gmovi.hora,
                                 'D', -- debito a la cuenta
                                 r_gmovi.cod_moneda,
                                 r_gmovi.monto,
                                 r_gmovi.cod_transaccion, -- trans. padre
                                 r_gmovi.cod_transaccion, -- trans. hijo
                                 null, -- nro_documento
                                 null, -- cotizacion
                                 r_gmovi.cod_ofi_origen, -- Oficina origen
                                 r_gmovi.cod_modulo,
                                 r_gmovi.cod_modalidad,
                                 null, -- tasa
                                 null, -- valor de tasa
                                 substr('Deb. Comisión uso ATM - Mto '||p.mto_recibido||' Cotización '||r_gmovi.cotizacion||' Ref:'||p.referencia,1,100), --concepto
                                 'N', -- emitir aviso
                                 r_gmovi.nro_secuencia, -- nro de secuencia
                                 r_gmovi.fecha);
        --Obtiene valores del impuesto.
        v_val_cargo := 0;
        v_cod_tra_impuesto := 0;
        v_cod_tas_impuesto := 0;
        v_val_tas_impuesto := 0;
        v_val_impuesto := 0;
        --
        prg_obt_car_impuesto(r_gmovi.cod_ofi_origen,
                             r_gmovi.nro_cuenta,
                             r_gmovi.cod_moneda,
                             r_gmovi.cod_modulo,
                             r_gmovi.cod_modalidad,
                             r_gmovi.cod_transaccion,
                             v_val_cargo,
                             v_cod_tra_impuesto,
                             v_cod_tas_impuesto,
                             v_val_tas_impuesto,
                             v_val_impuesto);
        --
        v_val_impuesto := round(nvl(r_gmovi.monto,0) * (v_val_tas_impuesto/100),v_decimales);
        --
        if v_val_impuesto > 0 and pag_cta.g_cod_error = 0 then
          -- Impuesto
          pag_cta.pr_act_operacion(r_gmovi.nro_cuenta,
                                   r_gmovi.hora,
                                   'D', -- debito a la cuenta del banco país
                                   r_gmovi.cod_moneda,
                                   v_val_impuesto,
                                   r_gmovi.cod_transaccion, -- trans. padre
                                   v_cod_tra_impuesto, -- trans. hijo
                                   null, -- nro_documento
                                   null, -- cotizacion
                                   r_gmovi.cod_ofi_origen, -- Oficina origen
                                   r_gmovi.cod_modulo,
                                   r_gmovi.cod_modalidad,
                                   v_cod_tas_impuesto, -- tasa
                                   v_val_tas_impuesto, -- valor de tasa
                                   'Deb. IVA s/Comisión por uso de ATM', --concepto
                                   'N', -- emitir aviso
                                   r_gmovi.nro_secuencia, -- nro de secuencia
                                   r_gmovi.fecha);
          if pag_cta.g_cod_error <> 0 then
            raise_application_error( -20000,pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error() );
          end if;
        else
          raise_application_error( -20000,pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error() );
        end if;
      end if;
    end if;
  end loop;
exception
  when others then
    raise_application_error(-20002,'Error al ejecutar Comisiones por Utilización de ATM. '||sqlerrm);
end;
/

