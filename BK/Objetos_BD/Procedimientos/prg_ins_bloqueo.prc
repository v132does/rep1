create or replace procedure it.prg_ins_bloqueo(p_nro_cuenta    in ge_embargos_det.nro_cuenta%type,
                                              p_monto         in ge_embargos.importe%type,
                                              p_cod_modalidad in pr_cta_prestamos.cod_modalidad%type) is
  --Procedimiento que genera un bloqueo a la cuenta si esta tiene
  --saldo de embargo pendiente
  
  PROCEDURE lp_ins_bloqueo(rp_bloqueo IN ge_bloqueos%ROWTYPE);
  v_causa          number(8);
  v_cotizacion     number(10);
  v_cod_tra        ge_movimientos.cod_transaccion%type;
  v_cod_embargo    ge_embargos.cod_embargo%type;
  v_cod_moneda     ge_embargos.cod_moneda%type;
  v_cod_ofi_origen ge_embargos.cod_ofi_origen%type;
  v_msj_error      varchar2(500);
  v_nro_secuencia  number(8) := 0;
  v_fec_hoy        ge_embargos.fecha%type;
  v_cotización     ge_embargos.cotizacion%type;
  r_gmovi          ge_movimientos%ROWTYPE;
  r_gbloqueo       ge_bloqueos%ROWTYPE;
  v_sal_embargo    ge_embargos.sal_embargo%type;
  v_monto_bloquear ge_embargos.importe%type;
  v_estado         ge_embargos.estado%type;
  v_act_estado     ge_embargos.estado%type := 'x';
  v_cod_modulo     ge_modalidades.cod_modulo%type;
  v_total          ge_embargos.importe%type;
  v_filas          varchar2(3) := 'NO';
  v_existe         varchar2(30):= 'NO';
  v_saldo_cta      ah_cta_vistas.sal_total%type := 0;
  v_sal_bloquear   ah_cta_vistas.sal_total%type := p_monto;

  --Procedimiento que inserta el registro a la tabla ge_bloqueos
  PROCEDURE lp_ins_bloqueo(rp_bloqueo IN ge_bloqueos%ROWTYPE) IS
  begin
 
  begin 
  Select 'SI'
    into v_existe 
  from ge_bloqueos 
  where nro_cuenta    = r_gbloqueo.nro_cuenta
    and fec_inicio    = r_gbloqueo.fec_inicio
    and nro_documento = r_gbloqueo.nro_documento;
    
  exception
    when no_data_found then 
      v_existe := 'NO';
    when others then 
      v_existe := 'NO';
  end;
  
  if v_existe = 'NO' then 
    insert into ge_bloqueos
      (nro_cuenta,
       nro_documento,
       fec_inicio,
       cod_causa,
       monto,
       mto_equivalente,
       cotizacion,
       hor_inicio,
       tipo)
    values
      (r_gbloqueo.nro_cuenta,
       r_gbloqueo.nro_documento,
       r_gbloqueo.fec_inicio,
       r_gbloqueo.cod_causa,
       r_gbloqueo.monto,
       (r_gbloqueo.monto * nvl(r_gbloqueo.cotizacion,1)),
       r_gbloqueo.cotizacion,
       r_gbloqueo.hor_inicio,
       r_gbloqueo.tipo);
  
  else 
          update ge_bloqueos c
         set fec_inicio      = r_gbloqueo.fec_inicio,
             cod_causa       = r_gbloqueo.cod_causa,
             c.monto         = nvl(c.monto,0) + r_gbloqueo.monto,
             mto_equivalente = (nvl(c.monto,0) + r_gbloqueo.monto)*(nvl(r_gbloqueo.cotizacion,1)),
             cotizacion      = r_gbloqueo.cotizacion,
             hor_inicio      = r_gbloqueo.hor_inicio,
             tipo            = r_gbloqueo.tipo
       where nro_cuenta = p_nro_cuenta
         and nro_documento = r_gbloqueo.nro_documento;     
  end if; 

  exception
    when others  then
     raise_application_error(-20007, SQLERRM);
  end;  -- end procedure lp_ins_bloqueo
  

begin
 -- solo si la cuenta tiene saldo se debe poder insertar el bloqueo y actualizar la cta
  Begin 
   if p_cod_modalidad in (41) then
       Select sum(sal_total)
         into v_saldo_cta 
       from cc_cta_corrientes v join ge_cta_clientes g on v.nro_cuenta = g.nro_cuenta and  g.relacion = 'P'
       where v.nro_Cuenta = p_nro_cuenta;      
   elsif p_cod_modalidad in (37,38) then
       Select sum(sal_total)
         into v_saldo_cta 
       from ah_cta_plazos v join ge_cta_clientes g on v.nro_cuenta = g.nro_cuenta and  g.relacion = 'P'
       where v.nro_Cuenta = p_nro_cuenta;           
   else  
       Select sum(sal_total) -- +p_monto) - (v.sal_retenido - v.sal_bloqueado)) 
         into v_saldo_cta 
       from ah_cta_vistas v join ge_cta_clientes g on v.nro_cuenta = g.nro_cuenta and  g.relacion = 'P'
       where v.nro_Cuenta = p_nro_cuenta; 
    end if;    
  exception 
    when no_data_found then
      v_saldo_cta := 0;
    when others then 
      v_saldo_cta := 0;
  end;
  
 if nvl(v_saldo_cta, 0) > 0 then

  --Obtener el codigo de la causa de bloqueo por embargo
  v_causa := FUG_OBT_PARDINAMICO('COD_CAU_BLO_EMBAR');

        --Obtener la transaccion para el bloqueo de la causa del embargo
        begin
          select val_parametro
            into v_cod_tra
            from ge_par_causales
           where cod_causa = v_causa
             and parametro = 'COD_CAU_BLO_TRANSACCION';
        exception
          when no_data_found then
            v_cod_tra := 604;
        end;

  --Obtener los datos del embargo
  begin
    select a.cod_embargo,
           a.cod_moneda,
           a.cod_ofi_origen,
           nvl(b.sal_embargo, 0),
           a.estado,
           c.cod_modulo,
           (nvl(a.importe,0) + nvl(a.gas_justicia,0)) total
      into v_cod_embargo,
           v_cod_moneda,
           v_cod_ofi_origen,
           v_sal_embargo,
           v_estado,
           v_cod_modulo,
           v_total
      from ge_embargos a, ge_embargos_det b, ge_cta_clientes c
     where a.cod_embargo = b.cod_embargo
       and b.nro_cuenta = p_nro_cuenta
       and b.nro_cuenta = c.nro_cuenta
       and b.sal_embargo > 0
       and c.relacion    = 'P'
       Order by a.fecha;
  exception
    WHEN no_data_found THEN
      v_msj_error := 'No existe saldo de embargo pendiente para la cuenta ' ||
                     p_nro_cuenta;
      raise_application_error(-20004, v_msj_error);
    WHEN TOO_MANY_ROWS THEN 
      v_filas := 'SI'; 
      DECLARE
       cursor c_lista_emb is 
        select a.cod_embargo,
             a.cod_moneda,
             a.cod_ofi_origen,
             nvl(b.sal_embargo, 0) saldo_embargo,
             a.estado,
             c.cod_modulo,
             (nvl(a.importe,0) + nvl(a.gas_justicia,0)) total

      from ge_embargos a, ge_embargos_det b, ge_cta_clientes c
     where a.cod_embargo = b.cod_embargo
       and b.nro_cuenta = p_nro_cuenta
       and b.nro_cuenta = c.nro_cuenta
       and b.sal_embargo > 0
       and c.relacion    = 'P'
       Order by a.fecha,a.cod_embargo;
       
       v_tot_embargos ge_embargos.importe%type := 0;
     
     BEGIN
       
         select sum((nvl(a.importe,0) + nvl(a.gas_justicia,0)) )total
           into v_tot_embargos  -- total de los embargos por esta cuenta 
      from ge_embargos a, ge_embargos_det b, ge_cta_clientes c
     where a.cod_embargo = b.cod_embargo
       and b.nro_cuenta = p_nro_cuenta
       and b.nro_cuenta = c.nro_cuenta
       and b.sal_embargo > 0
       and c.relacion    = 'P'
       Order by a.fecha, a.cod_embargo;
     
     
for i in c_lista_emb loop 
    
  --if v_tot_embargos > p_monto then   
       --Si el saldo de embargo es mayor al monto del crédito
  if i.saldo_embargo >= v_sal_bloquear then
    --El importe a bloquear será el monto del crédito
    v_monto_bloquear := v_sal_bloquear;
    v_act_estado     := 'N';
  else
     if v_sal_bloquear >= i.saldo_embargo then 
      v_monto_bloquear := i.saldo_embargo ;
      v_act_estado     := 'S'; 
     else 
    --Si el saldo de embargo es menor o igual al monto del crédito
    --el importe a bloquear será el saldo del embargo
    v_monto_bloquear :=  v_sal_bloquear; -- i.saldo_embargo ;
    v_act_estado     := 'S';
     end if;
    
  end if;

  --Obtener la fecha y cotización del día
  v_fec_hoy    := pae_cnf.fu_obt_fec_actual(i.cod_modulo);
  v_cotización := pag_gen.FU_OBT_COTIZACION(i.cod_moneda, v_fec_hoy);

  v_nro_secuencia := v_nro_secuencia + 1;
  
  --Actualizar el saldo bloqueado
  pag_cta.pr_act_operacion(p_nro_cuenta,
                           TO_CHAR(SYSDATE, 'HH24:MI:SS'), --hora
                           'C',
                           i.cod_moneda, --moneda
                           v_monto_bloquear, --monto
                           111, --transaccion padre
                           v_cod_tra, --codigo transaccion
                           i.cod_embargo, --codigo de embargo
                           NULL, --COTIZACION
                           i.cod_ofi_origen, --cod_ofi_origen
                           i.cod_modulo, --cod_mod_padre
                           p_cod_modalidad, --cod_mad_padre
                           null, --cod_tasa
                           null, --val_tasa
                           null,
                           'S', --emi_aviso
                           v_nro_secuencia, --secuencia
                           v_fec_hoy, --fecha de hoy
                           null,
                           v_causa);

  --Asingar los valores a las variables e insertar el bloqueo de la cuenta
  r_gbloqueo.nro_cuenta      := p_nro_cuenta;
  r_gbloqueo.nro_documento   := i.cod_embargo;
  r_gbloqueo.fec_inicio      := v_fec_hoy;
  r_gbloqueo.cod_causa       := v_causa;
  r_gbloqueo.monto           := v_monto_bloquear; --p_monto;
  r_gbloqueo.mto_equivalente := v_monto_bloquear;
  r_gbloqueo.cotizacion      := v_cotización;
  r_gbloqueo.hor_inicio      := TO_CHAR(SYSDATE, 'HH24:MI:SS');
  r_gbloqueo.tipo            := 'S';
  lp_ins_bloqueo(r_gbloqueo);

  if v_act_estado = 'S' then
    --Si se debe actualizar el estado
    if v_estado = 'AP' then
      --Si estado = AP (Aplicado Parcialmente), entonces actualizar a A (Aplicado)
      update ge_embargos h
         set h.estado = 'A'
       where h.cod_embargo = v_cod_embargo;
    end if;
  end if;

  --Se actualiza la cabecera del embargo, descontando a sal_embargo y sumando a mto_aplicado 
  --el monto a bloquear
 begin
    update ge_embargos_det a
       set a.sal_embargo  = a.sal_embargo - v_monto_bloquear,
           a.mto_aplicado = a.mto_aplicado + v_monto_bloquear
     where a.cod_embargo = i.cod_embargo
       and a.nro_cuenta = p_nro_cuenta;
  exception
    WHEN OTHERS THEN
      raise_application_error(-20006, SQLERRM);
  end;

  --Se actualiza el detalle del embargo, descontando a sal_embargo y sumando a mto_aplicado 
  --el monto a bloquear
  begin
    update ge_embargos a
       set a.sal_embargo  = a.sal_embargo - v_monto_bloquear,
           a.mto_aplicado = a.mto_aplicado + v_monto_bloquear
     where a.cod_embargo = i.cod_embargo;
  exception
    WHEN OTHERS THEN
      raise_application_error(-20007, SQLERRM);
  end;
  
  v_sal_bloquear := v_sal_bloquear - v_monto_bloquear;
  
  /*si ya se aplico el monto total debe salir ya del cursor*/
  EXIT  WHEN v_sal_bloquear <= 0 ; 

 end loop;
     
     EXCEPTION
       WHEN OTHERS THEN 
      raise_application_error(-20009, 'Verificar: '|| sqlerrm);
      
     END;
    
    WHEN OTHERS THEN
      raise_application_error(-20005, SQLERRM);
  end;

if v_filas = 'NO' then
  --Si el saldo de embargo es mayor al monto del crédito
  if v_sal_embargo > p_monto then
    --El importe a bloquear será el monto del crédito
    v_monto_bloquear := p_monto;
    v_act_estado     := 'N';
  else
    --Si el saldo de embargo es menor o igual al monto del crédito
    --el importe a bloquear será el saldo del embargo
    v_monto_bloquear := v_sal_embargo;
    v_act_estado     := 'S';
  end if;

  --Obtener la fecha y cotización del día
  v_fec_hoy    := pae_cnf.fu_obt_fec_actual(v_cod_modulo);
  v_cotización := pag_gen.FU_OBT_COTIZACION(v_cod_moneda, v_fec_hoy);

  v_nro_secuencia := v_nro_secuencia + 1;
  --Actualizar el saldo bloqueado
  pag_cta.pr_act_operacion(p_nro_cuenta,
                           TO_CHAR(SYSDATE, 'HH24:MI:SS'), --hora
                           'C',
                           v_cod_moneda, --moneda
                           v_monto_bloquear, --monto
                           111, --transaccion padre
                           v_cod_tra, --codigo transaccion
                           v_cod_embargo, --codigo de embargo
                           NULL, --COTIZACION
                           v_cod_ofi_origen, --cod_ofi_origen
                           v_cod_modulo, --cod_mod_padre
                           p_cod_modalidad, --cod_mad_padre
                           null, --cod_tasa
                           null, --val_tasa
                           null,
                           'S', --emi_aviso
                           v_nro_secuencia, --secuencia
                           v_fec_hoy, --fecha de hoy
                           null,
                           v_causa);

  --Asingar los valores a las variables e insertar el bloqueo de la cuenta
  r_gbloqueo.nro_cuenta      := p_nro_cuenta;
  r_gbloqueo.nro_documento   := v_cod_embargo;
  r_gbloqueo.fec_inicio      := v_fec_hoy;
  r_gbloqueo.cod_causa       := v_causa;
  r_gbloqueo.monto           := v_monto_bloquear; --p_monto;
  r_gbloqueo.mto_equivalente := v_monto_bloquear;
  r_gbloqueo.cotizacion      := v_cotización;
  r_gbloqueo.hor_inicio      := TO_CHAR(SYSDATE, 'HH24:MI:SS');
  r_gbloqueo.tipo            := 'S';
  lp_ins_bloqueo(r_gbloqueo);

  if v_act_estado = 'S' then
    --Si se debe actualizar el estado
    if v_estado = 'AP' then
      --Si estado = AP (Aplicado Parcialmente), entonces actualizar a A (Aplicado)
      update ge_embargos h
         set h.estado = 'A'
       where h.cod_embargo = v_cod_embargo;
    end if;
  end if;

  --Se actualiza la cabecera del embargo, descontando a sal_embargo y sumando a mto_aplicado 
  --el monto a bloquear
  begin
    update ge_embargos_det a
       set a.sal_embargo  = a.sal_embargo - v_monto_bloquear,
           a.mto_aplicado = a.mto_aplicado + v_monto_bloquear
     where a.cod_embargo = v_cod_embargo
       and a.nro_cuenta = p_nro_cuenta;
  exception
    WHEN OTHERS THEN
      raise_application_error(-20006, SQLERRM);
  end;

  --Se actualiza el detalle del embargo, descontando a sal_embargo y sumando a mto_aplicado 
  --el monto a bloquear
  begin
    update ge_embargos a
       set a.sal_embargo  = a.sal_embargo - v_monto_bloquear,
           a.mto_aplicado = a.mto_aplicado + v_monto_bloquear
     where a.cod_embargo = v_cod_embargo;
  exception
    WHEN OTHERS THEN
      raise_application_error(-20007, SQLERRM);
  end;

end if;

end if;


end prg_ins_bloqueo;
/

