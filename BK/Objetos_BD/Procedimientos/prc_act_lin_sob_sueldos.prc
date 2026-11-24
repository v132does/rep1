create or replace procedure it.PRC_ACT_LIN_SOB_SUELDOS is

  v_nro_cuenta        cc_lin_sobregiros.nro_cuenta%type;
  v_nro_sec_padre     cc_lin_sobregiros.nro_secuencia%type;
  v_nro_sec_padre_his cc_lin_sobregiros.nro_secuencia%type;
  v_nro_secuencia     cc_lin_sobregiros.nro_secuencia%type;
  v_estado            cc_lin_sobregiros.estado%type;
  v_observacion       cc_lin_sobregiros.observacion%type;
  v_insertar          varchar2(1);
  v_monto_det         number(18,2);
  v_monto_cab         number(18,2);
  v_can_automatica    varchar2(1);
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(4);
  v_rowid_det         rowid;
  v_rowid_cab         rowid;
  v_tipo              cc_lin_sobregiros.tipo%type;

  --Cursor de Cuentas que recibieron crédito en la fecha y tuvieron
  --cancelación de linea anteriormente
  cursor cur_cte is
    select distinct t.nro_cuenta
      from ge_pag_sueldos t, cc_cta_corrientes c
     where t.nro_cuenta = c.nro_cuenta
       and t.fec_proceso = v_fec_actual
       and t.procesado = 'S'
       and t.tipo = 'C'
       and c.acu_sobregiro = 'N'
       and not exists (select 1
              from cc_lin_sobregiros x
             where x.nro_cuenta = t.nro_cuenta
               and x.estado in ('A', 'V'))
       and exists (select 1
              from cc_lin_sobregiros_his h
             where h.nro_cuenta = t.nro_cuenta
               and h.estado = 'C'
               and h.can_automatica = 'S'
               and not exists (Select 1 from ba_tab_dat_adicionales n
                       where n.tab_relacion = 'CC_LIN_SOBREGIROS'
                         and n.parametro = 'NRO_CTA_RELACIONADA'
                         and n.val_parametro = h.nro_cuenta
                         and n.referencia = h.nro_secuencia)); -- OMM 12/08/2015: Verifica si existe sobregiro aprobado por campaña

  --Historico de lineas de sobregiros x Cuenta
  cursor cur_his_det is
    select x.nro_sec_padre, x.estado, x.can_automatica, x.monto, x.rowid
      from cc_lin_sobregiros_his x
     where x.nro_cuenta = v_nro_cuenta
     order by x.fec_insercion desc;

function lf_obt_lin_sobregiro(p_nro_cuenta varchar2,
                              p_tipo       varchar2)
  return varchar2 is
  v_existe varchar2(1):= 'N';
begin
  begin
    select distinct 'S'
      into v_existe
      from cc_lin_sobregiros
     where nro_cuenta = p_nro_cuenta
       and tipo       = p_tipo;
  exception
    when no_data_found then
      v_existe := 'N';
    when others then
      v_existe := 'S';
  end;
  return v_existe;
end;

begin
  if cur_his_det%isopen then
    close cur_his_det;
  end if;

  v_observacion := '* '||to_char(v_fec_actual,'dd/mm/yyyy')||' - Línea Reactivada por Crédito de Sueldo';

  for k in cur_cte loop
    v_insertar   := 'S';
    v_nro_cuenta := k.nro_cuenta;
    open cur_his_det;
    fetch cur_his_det
      into v_nro_sec_padre_his,v_estado,v_can_automatica,v_monto_det,v_rowid_det;
    if cur_his_det%found then
      --Si el ultimo estado en el Historico es Cancelado Automaticamente
      if v_estado = 'C' and nvl(v_can_automatica,'N') = 'S' then
        begin
          --Recuperar rowid de registro Cabecera
          select rowid, x.monto, x.tipo
            into v_rowid_cab, v_monto_cab, v_tipo
            from cc_lin_sobregiros_his x
           where x.nro_secuencia = v_nro_sec_padre_his
             and x.can_automatica = 'S'
             and x.fec_insercion =(select max(fec_insercion)
                                     from cc_lin_sobregiros_his j
                                    where j.nro_secuencia = v_nro_sec_padre_his
                                      and j.can_automatica = 'S');
          if v_monto_det > v_monto_cab then
            v_insertar := 'N';
          end if;
        exception
          when others then
             v_insertar := 'N'; --No se encontro el registro o esta duplicado
        end;

        --Verificar que no exista una línea p/ la cuenta
        if lf_obt_lin_sobregiro(k.nro_cuenta,v_tipo) = 'S' then
           v_insertar := 'N';
        end if;

        if v_insertar = 'S' then
          --Generar Nuevo Nro. de Secuencia Padre
          select s_nro_lin_sobregiro.nextval into v_nro_sec_padre from dual;

          --Insertar Registro Cabecera
          insert into cc_lin_sobregiros
           (nro_cuenta, fec_vencimiento, fec_inicio, nro_secuencia, monto, tipo, cod_persona, cod_moneda, estado, nro_sec_padre, observacion, niv_aprobacion)
          select null, v_fec_actual + 30, v_fec_actual, v_nro_sec_padre, x.monto, x.tipo, x.cod_persona, x.cod_moneda, 'A', null, v_observacion, x.niv_aprobacion
            from cc_lin_sobregiros_his x
           where x.rowid = v_rowid_cab;

          --Generar Nuevo Nro. de Secuencia
          select s_nro_lin_sobregiro.nextval into v_nro_secuencia from dual;

          --Insertar Registro Detalle
          insert into cc_lin_sobregiros
           (nro_cuenta, fec_vencimiento, fec_inicio, nro_secuencia, monto, tipo, cod_persona, cod_moneda, estado, nro_sec_padre, observacion, niv_aprobacion)
          select x.nro_cuenta, v_fec_actual + 30, v_fec_actual, v_nro_secuencia, x.monto, x.tipo, null, x.cod_moneda, 'A', v_nro_sec_padre, v_observacion, x.niv_aprobacion
            from cc_lin_sobregiros_his x
           where x.rowid = v_rowid_det;

          --Insertar Registro Garantia
          insert into cc_lin_sob_garantias
            (mto_aplicado, nro_secuencia, cod_garantia)
          values
            (v_monto_cab, v_nro_sec_padre, 1);

          --Actualizar CC_CTA_CORRIENTES
          update cc_cta_corrientes c
             set c.acu_sobregiro = 'S'
           where c.nro_cuenta = v_nro_cuenta;
        end if;
      end if;
    end if;
    close cur_his_det;
  end loop;

exception
  when others then
    if sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,
                              'PRC_ACT_LIN_SOB_SUELDOS: Cta.: ' ||
                              v_nro_cuenta || '; Sec.: ' || v_nro_sec_padre || '.' ||
                              SQLERRM);
    end if;
end PRC_ACT_LIN_SOB_SUELDOS;
/

