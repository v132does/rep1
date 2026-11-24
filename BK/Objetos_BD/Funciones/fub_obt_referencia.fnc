CREATE OR REPLACE FUNCTION IT."FUB_OBT_REFERENCIA" (p_rowid varchar2) return varchar2 is
  v_concepto        ge_con_transacciones.concepto%type;
  v_nro_doc_persona varchar2(30);
  v_nom_completo    varchar2(200);
  v_cod_rubro       varchar2(20);
  v_gmov ge_movimientos%rowtype;
  v_afe_transferencia varchar2(1);
  v_afe_libranza      varchar2(1);
  v_id_sesion         ge_spi_transferencias.id_sesion%type;
begin
  select *
    into v_gmov
    from ge_movimientos --ge_mov
   where rowid = p_rowid;
  --
  if v_gmov.cod_mod_padre = 7 and v_gmov.nro_secuencia in (1,2) and v_gmov.cod_tip_ope_cambio is not null then
     begin
        select nvl(afe_transferencia,'N'), NVL(afe_libranza,'N')
          into v_afe_transferencia, v_afe_libranza
          from lc_tip_operaciones
         where cod_tip_operacion = v_gmov.cod_tip_ope_cambio;
     exception
        when others then
             v_afe_transferencia := 'N';
             v_afe_libranza := 'N';
     end;
  end if;
  --
  if v_gmov.cod_modalidad = 72 and v_gmov.cod_transaccion = 785 then
    -- detalle especial de transacciones de desglose de comisiones por operaciones de cmbios
    v_concepto := substr('/011/'||lpad(nvl(v_gmov.cod_persona,'999999'),6,'0')||'/'||fue_obt_nom_persona(v_gmov.cod_persona),1,100);
  elsif v_gmov.cod_mod_padre = 7 and  (NVL(v_afe_transferencia,'N') = 'S' or NVL(v_afe_libranza,'N') = 'S') then
    -- compra de transferencias o venta de transferencias
    begin
       select substr('//'||nro_ref_externa||'//'||nom_beneficiario,1,100)
         into v_concepto
         from lc_transferencias x
        where (x.nro_operacion = v_gmov.nro_documento and v_afe_transferencia = 'S') or
              (x.cod_tip_referencia= v_gmov.cod_ref_cambio and x.nro_referencia= v_gmov.nro_documento2 and v_afe_libranza = 'S');
    exception
       when others then
          null;
    end;
/*  elsif pab_iva.FU_MOV_CON_IVA(v_gmov.cod_modulo, v_gmov.cod_modalidad, v_gmov.cod_transaccion) = 'S' then
    -- es una transaccion de iva
    if v_gmov.monto > 0 then
      v_concepto := '/901/';
    else
      v_concepto := '/902/';
    end if;
    if v_gmov.cod_persona is null then
      pab_iva.PR_OBT_DAT_PERSONA(v_gmov.COD_MOD_PADRE,v_gmov.cod_usuario,v_gmov.fecha, v_gmov.hora, null, v_gmov.nro_cuenta, v_gmov.nro_documento2,
                                 v_gmov.referencia, null, null, null, v_gmov.cod_persona, v_nro_doc_persona, v_nom_completo);
    end if;
    v_concepto := v_concepto || lpad(nvl(v_gmov.cod_persona,'999999'),6,'0');
    v_cod_rubro := pab_iva.FU_OBT_RUB_CARGO(v_gmov.fecha,v_gmov.cod_usuario,v_gmov.hora,v_gmov.nro_secuencia);
    begin
      select cod_rub_externo
        into v_cod_rubro
        from cb_rubros
       where cod_rubro = v_cod_rubro;
    exception
       when others then
         v_cod_rubro := null;
    end;
    v_concepto := v_concepto ||'/'||v_cod_rubro;*/
  elsif v_gmov.cod_mod_padre = 7 and v_gmov.cod_transaccion in(842,741) and
    v_gmov.cod_rubro in (240402600288810, 240402600288814, 240402600288807, 240402600288803, 240402600288805, 240402600288817, 240402600288899, 240402600288828)
    and v_gmov.concepto like '%Cambios%' then
                     v_concepto:='/CAMBIOS/'||v_gmov.cod_persona;
  elsif v_gmov.cod_mod_padre = 7 and v_gmov.cod_transaccion in(842,741) and
    v_gmov.cod_rubro in (240402600288810, 240402600288814, 240402600288807, 240402600288803, 240402600288805, 240402600288817, 240402600288899, 240402600288828)
    and v_gmov.reversado='S' and v_gmov.monto < 0 then
                     v_concepto:='/CAMBIOS/'||v_gmov.cod_persona;
  elsif v_gmov.cod_transaccion=842 and trim(v_gmov.concepto)='Cheque gerencia' and v_gmov.tip_mov_rubro='D' and v_gmov.reversado='N' then
      begin
          select concepto into v_concepto from ge_movimientos
          where fecha =to_date('18052010','ddmmyyyy')
          and hora=v_gmov.hora
          and cod_usuario=v_gmov.cod_usuario
          and monto=v_gmov.monto
          and cod_moneda=v_gmov.cod_moneda
          and tip_mov_rubro='C';
          --and cod_rubro in(240402600201205,111201090300205);
      exception when others then
           v_concepto:=null;
      end;
  elsif v_gmov.cod_mod_padre = 4 and v_gmov.cod_mad_padre= 41 and v_gmov.cod_tra_padre = 227 and v_gmov.cod_moneda = 'GS' and v_gmov.cod_transaccion=503 then
        v_concepto := v_gmov.nro_documento3||' '||v_gmov.concepto;
  else

    --para obtener el concepto originar de los prestamos automaticos
    if v_gmov.cod_transaccion in(5503,6602) then
       v_concepto := v_gmov.concepto;
    elsif v_gmov.cod_transaccion in(3602, 3503, 8503) then
       select decode(substr(v_gmov.concepto,0,4),'BAJA',
              substr(v_gmov.concepto,instr(v_gmov.concepto,'/'),30),
              v_gmov.concepto) into v_concepto from dual;
    else
        if v_gmov.cod_moneda='USD' and v_gmov.concepto='HSBC' then
           begin
               select observacion into v_concepto from lc_ope_pendientes z where z.nro_operacion=v_gmov.nro_documento;
               v_concepto:=v_gmov.concepto||'-'||v_concepto;
           exception when others then
               v_concepto:=null;
           end;
        end if;
    end if;
  end if;
  
  --BSEVOCORE-1063 SPI - Visualizar ID. de Mensaje (concepto del movimiento)
  if v_gmov.cod_tra_padre = 303 and v_gmov.cod_transaccion in (247,248) then
    begin
      select a.id_sesion
        into v_id_sesion
        from ge_spi_transferencias a
       where a.nro_referencia = v_gmov.nro_documento;
    exception
      when others then
        null;
    end;
    v_concepto := v_gmov.concepto||'-'||v_id_sesion;
    v_concepto := substr(v_concepto,1,60);
  end if;
  return v_concepto;
end;
/

