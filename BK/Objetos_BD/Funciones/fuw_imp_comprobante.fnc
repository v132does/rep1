CREATE OR REPLACE FUNCTION IT.FUW_IMP_COMPROBANTE
  (P_NRO_CUENTA    in varchar2, --nro de cuenta o tarjeta
   P_FECHA         in GE_MOVIMIENTOS.FECHA%TYPE,
   P_NRO_DOCUMENTO in GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE,
   P_MONTO         in GE_MOVIMIENTOS.MONTO%TYPE,
   P_TIPO          in GE_TRANSACCIONES.TIPO%TYPE,
   P_FACTURA       in varchar2,
   P_NRO_SECUENCIA in GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE DEFAULT NULL)
  return clob is
  
  --devuelve los datos del movimiento en formato html para imprimir el comprobante en la web
  v_des_tra_padre   ge_transacciones.descripcion%type;
  v_cod_moneda      ge_movimientos.cod_moneda%type; 
  v_cod_transaccion ge_movimientos.cod_transaccion%type;
  v_cod_banco       ge_movimientos.cod_banco%type;
  v_nro_caja        ge_movimientos.nro_caja%type;
  v_concepto        ge_movimientos.concepto%type;
  v_ofi_origen      ge_movimientos.cod_ofi_origen%type;
  v_cod_oficina     ge_movimientos.cod_oficina%type;
  v_hora            ge_movimientos.hora%type;
  v_tip_cta         ge_modalidades.descripcion%type;
  v_cod_usuario     ge_movimientos.cod_usuario%type;
  v_nro_secuencia   ge_movimientos.nro_secuencia%type;
  v_nro_cuenta      ge_movimientos.nro_cuenta%type;
  v_nro_cta_mov     ge_movimientos.nro_cuenta%type;
  v_cod_tra_padre   ge_movimientos.cod_tra_padre%type;
  v_monto           ge_movimientos.monto%type;
  v_det_descripcion ge_transacciones.descripcion%type;
  v_snp_nro_cta_beneficiario ge_snp_transferencias.nro_cta_beneficiario%type;
  v_snp_monto ge_snp_transferencias.monto%type;
  v_snp_cod_moneda ge_snp_transferencias.cod_moneda%type;
  v_snp_cod_swi_pte_beneficiario ge_snp_transferencias.cod_swi_pte_beneficiario%type;
  v_snp_nom_beneficiario ge_snp_transferencias.nom_beneficiario%type;
  v_situacion       varchar2(100);
  v_estado          varchar2(100);
  v_msj_swift       varchar2(1000);
  v_tip_mt          varchar2(20);
  v_fila            varchar2(200);  
  v_cta_formateada  varchar2(20);  
  v_tip_mov         varchar2(15);
  v_error           varchar2(1000);    
  v_tiene_factura   varchar2(1) := 'N';
  v_cantidad        number;
  v_cod_modulo      number(5);
  v_cod_modalidad   number(5);  
  v_cont            number:= 0;
  v_primero         boolean := true;
  v_retorno         clob := null;
  -- JIRA 1584
  v_nro_documento3  ge_movimientos.nro_documento3%type := null;
  v_nro_documento ge_movimientos.nro_documento%type := null;
  v_ref_factauras   ge_pag_proveedores.ref_facturas%type := null;
  --                      
  
  --detalles del movimiento
  cursor detalles is
    select decode(a.cod_tra_padre,v_cod_tra_padre,b.descripcion,c.descripcion) descripcion, fug_obt_des_modal(a.cod_modulo,a.cod_modalidad), 
           decode(a.nro_cuenta,null,nvl(a.TIP_MOV_RUBRO,fug_obt_tip_mov_contable(a.cod_modulo,a.cod_modalidad,a.cod_transaccion)),
           decode(a.cod_modulo,3,b.tipo,4,b.tipo,nvl(a.TIP_MOV_RUBRO,fug_obt_tip_mov_contable(a.cod_modulo,a.cod_modalidad,a.cod_transaccion)))) tipo,
           a.cod_moneda, rownum,  a.cod_transaccion, a.cod_banco,
           decode(a.cod_modulo,5,fut_obt_nro_tarjeta(a.nro_cuenta), a.nro_cuenta) nro_cuenta, a.monto,
           a.nro_caja, a.concepto, a.cod_ofi_origen, a.hora, cod_oficina, a.cod_modulo cod_modulo, nro_documento3,
           decode(a.nro_cuenta, null, null, fug_cta_formateada(a.cod_modulo,a.cod_modalidad, a.cod_oficina,a.nro_cuenta,a.cod_moneda)) cta_formateada,
           a.cod_modulo modulo, a.cod_modalidad modalidad, to_char(pc.fec_vencimiento, 'dd/mm/yyyy') fec_vencimiento
      from ge_transacciones c, ge_transacciones b, gv_movimientos a, pr_cuotas pc
     where a.reversado = 'N'
       and a.fecha = p_fecha
       and a.hora = v_hora
       and a.cod_usuario = v_cod_usuario
       and a.cod_transaccion = b.cod_transaccion
       and a.cod_modulo = b.cod_modulo
       and a.cod_modalidad = b.cod_modalidad
       and a.estado = 'N'
       and b.ve_cliente = 'S'
       and a.nro_secuencia <> v_nro_secuencia --para q no traiga el principal otra vez
       and (a.nro_cuenta <> v_nro_cuenta or a.nro_cuenta is null) --para q no traiga otro débito o crédito a la cuenta
       and a.monto > 0
       --and a.nro_documento = p_nro_documento -- para pagos en batch, hay movimientos con misma hora y fecha
       and ((v_cod_tra_padre not in (360, 361, 362, 359) and a.nro_documento = p_nro_documento) OR
                 v_cod_tra_padre in (360, 361, 362, 359)
                ) -- para pagos en batch, hay movimientos con misma hora y fecha, se excluyen prestamos
                  -- que no tienen el mismo numero de documento para los movimientos registrados
       and (a.nro_cuenta = v_nro_cta_mov or v_nro_cta_mov is null)
       and a.cod_tra_padre = c.cod_transaccion
       and a.cod_mod_padre = c.cod_modulo
       and a.cod_mad_padre = c.cod_modalidad
       and ((a.cod_modulo <> 4) or (a.cod_modulo = 4 and a.cod_modalidad = 41))
       and pc.nro_cuenta(+) = a.NRO_CUENTA
       and pc.nro_cuota(+) = a.NRO_DOCUMENTO3
     order by nro_secuencia;

  function lf_cta_relacionadas(p_nro_cuenta1 in varchar2, p_nro_cuenta2 in varchar2)
    return varchar2 is 
    v_sino varchar2(1) := 'N';
  begin
     if p_nro_cuenta1 = v_nro_cuenta and v_tip_mov = 'D&eacute;bito' then
        return 'S';
     else   
       select 'S'
         into v_sino
         from ge_cta_clientes a
        where a.nro_cuenta = p_nro_cuenta1
          and exists (select 0 from ge_cta_clientes b
                       where b.nro_cuenta = p_nro_cuenta2
                         and b.cod_persona = a.cod_persona)
          and rownum = 1;
     end if;   
     return v_sino;   
  exception        
     when others then 
        return 'N';
  end;         
  
  --CR: para separar las facturas largas
  function lf_sep_facturas(p_facturas in varchar2, p_max_longitud in integer) 
    return varchar2 is
  v_posicion      integer := 0;
  v_pos_anterior  integer := length(p_facturas);
  v_indice        integer := 1;
  v_fac_separadas varchar2(1000) := '';
  v_separador     varchar2(1) := ';';
  begin
    if instr(p_facturas, ',') > 0 then
      v_separador := ',';
    end if;
    loop
      v_posicion := instr(p_facturas,v_separador,v_posicion + 1);
      exit when v_posicion = 0;    
      if (v_posicion - v_indice) >= p_max_longitud then
        v_fac_separadas := v_fac_separadas || substr(p_facturas, v_indice, v_pos_anterior)||'<br>';
        v_indice := v_pos_anterior + 1;
      end if;
      v_pos_anterior := v_posicion;      
    end loop;
    v_fac_separadas := v_fac_separadas || substr(p_facturas, v_indice, v_pos_anterior);
    return v_fac_separadas;
  exception
    when others then
      return p_facturas;  
  end;
     
begin
  
  --identifica si el parámetro es una cuenta o una tarjeta
  if length(p_nro_cuenta) = 16 then
     -- es un tarjeta de crédito
     begin
        select nro_cuenta
          into v_nro_cuenta
          from ta_tarjetas b
         where b.nro_tarjeta = p_nro_cuenta;
     exception
       when no_data_found then
         v_error := 'No existe Tarjeta de Crédito. Avise al Oficial.';
       when others then
         v_error := 'No se puede imprimir el Comprobante. Recup.Tarj.Crédito ' || sqlerrm;
     end;
  else
     v_nro_cuenta := p_nro_cuenta;
  end if;
  --recupera el movimiento principal
  begin
     if p_tipo = 'I' then -- Transferencia Interbancaria
        Select decode(length(gs.nro_cta_beneficiario),16,'PAGO DE TARJETA OTROS BCOS','TRANSFERENCIA A OTROS BANCOS'),
               null, null, gs.cod_moneda, 1, null, null, gs.usu_insercion, null, 
               decode(length(gs.nro_cta_beneficiario),16,'Pago de Tarjeta Otros Bcos','Transferencia a otros Bancos'),
               gs.cod_oficina, null, gs.cod_oficina, null, gs.nro_cta_solicitante, null, null, gs.monto,
               FUE_OBT_DES_REFCODES('SITUACION',gs.situacion) Situacion, 
               FUE_OBT_DES_REFCODES('EST_MSJ_SNP',gs.estado) Estado, gs.msj_swift,
               decode(gs.ind_valor,'S','Alto Valor','Bajo Valor')
          into v_des_tra_padre, v_tip_cta, v_tip_mov, v_cod_moneda, v_fila, v_cod_transaccion, v_cod_banco, v_cod_usuario, 
               v_nro_caja, v_concepto, v_ofi_origen, v_hora, v_cod_oficina, v_nro_secuencia, v_cta_formateada, v_cod_tra_padre,
               v_cod_modulo, v_monto, v_situacion, v_estado, v_msj_swift, v_tip_mt
          from ge_snp_transferencias gs
         where gs.nro_referencia = p_nro_cuenta ;
     else
       select c.descripcion, fug_obt_des_modal(a.cod_modulo,a.cod_modalidad), decode(p_tipo,'D','D&eacute;bito','Cr&eacute;dito'),
              a.cod_moneda, rownum,  a.cod_transaccion, a.cod_banco, cod_usuario, 
              a.nro_caja, a.concepto, a.cod_ofi_origen, a.hora, cod_oficina, nro_secuencia,
              fug_cta_formateada(a.cod_modulo,a.cod_modalidad, a.cod_oficina,a.nro_cuenta,a.cod_moneda), a.cod_tra_padre,
              a.cod_modulo, a.cod_modalidad, a.monto, a.nro_documento3, a.nro_documento
         into v_des_tra_padre, v_tip_cta, v_tip_mov, v_cod_moneda, v_fila, v_cod_transaccion, v_cod_banco, v_cod_usuario, 
              v_nro_caja, v_concepto, v_ofi_origen, v_hora, v_cod_oficina, v_nro_secuencia, v_cta_formateada, v_cod_tra_padre,
              v_cod_modulo, v_cod_modalidad, v_monto, v_nro_documento3,v_nro_documento
         from ge_transacciones c, ge_transacciones b, gv_movimientos a
        where ((nvl(a.nro_documento, p_nro_documento) = p_nro_documento or p_nro_documento is null) or
              (a.COD_MAD_PADRE = 455 and substr(a.nro_documento,-7) = p_nro_documento)) -- SNP
          and (a.nro_secuencia = p_nro_secuencia or p_nro_secuencia is null) -- JIRA 1584: se agrega nro_secuencia
          and a.reversado = 'N'
          and a.estado = 'N'
          and a.nro_cuenta = v_nro_cuenta
          and a.fecha = p_fecha
          and a.monto = p_monto
          and b.tipo = p_tipo
          and a.cod_transaccion = b.cod_transaccion
          and a.cod_modulo = b.cod_modulo
          and a.cod_modalidad = b.cod_modalidad
          and a.cod_tra_padre = c.cod_transaccion
          and a.cod_mod_padre = c.cod_modulo
          and a.cod_mad_padre = c.cod_modalidad; 
        if v_des_tra_padre = 'COBRO DE PRESTAMOS POR CAJA' and v_nro_caja is null then
           v_des_tra_padre := 'COBRO DE PR&Eacute;STAMOS POR BBVA NET';
        end if; 
      end if ;
  exception
     when no_data_found then
       v_error := 'Movimiento no tiene Comprobante.';
     when too_many_rows then
       v_error := 'Varios Comprobantes con el mismo criterio, no se puede imprimir. Avise al Oficial.';
     when others then
       v_error := 'No se puede imprimir el Comprobante. ' || sqlerrm;
  end;
  
  -- JIRA 1584 Obtenemos las facturas pagadas para pago a proveedores
  if v_cod_tra_padre in (346, 348) and p_tipo = 'C' then
    begin
      select nvl(gpp.ref_facturas, gpp.nro_factura)
        into v_ref_factauras
        from ge_pag_proveedores gpp 
       where gpp.cod_ente = v_nro_documento3
         and gpp.fec_pago = p_fecha
         and gpp.nro_cta_credito = v_nro_cuenta
         and gpp.monto = p_monto
         and gpp.referencia = p_nro_documento;
    exception
      when others then
        v_ref_factauras := null;
    end;
  end if;
  
  if p_tipo = 'D' and 
     (trim(v_concepto) = 'Pago de Sueldo' or trim(v_concepto) like 'Débito por %: Empresa %' 
      or v_cod_tra_padre in (360, 361, 362, 359))  then -- JIRA 1584
     v_nro_cta_mov := null; --tomar todos los detalles ya que son de la cuenta
  elsif trim(v_concepto) like 'Imp:%Desp%' then
     v_nro_cta_mov := v_nro_cuenta; --son mov de pago de despachos, sólo tomar el de la cuenta   
  else   
    --busca si hay más movimientos de otras cuentas para el movimiento principal -> son movimientos masivos
/*    select count(distinct(nro_cuenta))
      into v_cantidad*/
    select count(0)
      into v_cantidad
      from 
      (
        select distinct nro_cuenta, a.cod_transaccion
          from ge_transacciones b, gv_movimientos a
         where a.reversado = 'N'
           and a.fecha = p_fecha
           and a.hora = v_hora
           and a.cod_usuario = v_cod_usuario
           and a.cod_transaccion = b.cod_transaccion
           and a.cod_modulo = b.cod_modulo
           and a.cod_modalidad = b.cod_modalidad
           and a.estado = 'N'
           and b.ve_cliente = 'S'
           and a.nro_cuenta is not null
           and a.nro_secuencia <> v_nro_secuencia
           and a.monto > 0
      );
    if v_cantidad > 2 or substr(v_cod_usuario,1,3) = 'ATM' then 
       v_nro_cta_mov := v_nro_cuenta; --son movimientos masivos o por ATM, sólo tomar el de la cuenta
    else
       v_nro_cta_mov := null; --tomar todos los detalles ya que son de la cuenta
    end if;
  end if;       
  if v_cta_formateada is not null then 
     if p_tipo = 'I' then
        pag_cta.PR_OBT_CUENTA(v_cta_formateada);
     else
        pag_cta.PR_OBT_CUENTA(v_nro_cuenta);
     end if ;
     IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
      v_error := 'Recup.Cta '||pag_cta.fu_obt_msj_error();
    END IF;
  end if;
  
  --arma html
  pag_htm.v_texto := null;-- inicializo el texto
  --  
  --si hubo error devolver el msj de error, sino imprimir comprobante
  if v_error is not null then
    pag_htm.PR_TABLA('S',630,50,0); -- DEFINO LA TABLA
      pag_htm.PR_COLUMNA(v_error,NULL,'center','S'); -- agrego la columna etiqueta
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    
  else
    pag_htm.PR_TABLA('S',630,50,0); -- DEFINO LA TABLA
      pag_htm.PR_COLUMNA(v_des_tra_padre,NULL,'center','S'); -- agrego la columna etiqueta
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal
    
    pag_htm.PR_TABLA('S',630,30,0); -- DEFINO LA TABLA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Cuenta:',120,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(v_cta_formateada ||' - ' ||pag_cta.FU_OBT_NOM_CUENTA,340); -- agrego la columna del nro de cuenta
      pag_htm.PR_COLUMNA(fue_obt_titulo(v_tip_cta),null,'left'); 
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    
    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Moneda:',120,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(FUE_OBT_DES_MONEDA(v_cod_moneda),340); -- agrego la columna del nro de cuenta
      pag_htm.PR_COLUMNA('Oficina:',40,'left','S');
      pag_htm.PR_COLUMNA(fue_obt_titulo(fue_obt_des_oficina(v_cod_oficina)));
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal
    
    pag_htm.PR_TABLA('S',630,50,0); -- DEFINO LA TABLA
      if v_ref_factauras is not null then -- JIRA 1584
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('Facturas Pagadas:',120,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA(lf_sep_facturas(v_ref_factauras, 80)); -- agrego la columna del nro de cuenta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      end if;
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      if v_des_tra_padre='TRANSFERENCIA INTERBANCARIA' then 
        select t.nro_cta_beneficiario, t.monto,t.cod_moneda,t.cod_swi_pte_beneficiario,t.nom_beneficiario
          into v_snp_nro_cta_beneficiario, v_snp_monto,v_snp_cod_moneda,v_snp_cod_swi_pte_beneficiario,v_snp_nom_beneficiario
          from ge_snp_transferencias t
        where t.nro_referencia=v_nro_documento;
      
        pag_htm.PR_COLUMNA('Nro. Transferencia:',120,'left','S'); -- agrego la columna etiqueta
      else
      pag_htm.PR_COLUMNA('Nro. Comprobante:',120,'left','S'); -- agrego la columna etiqueta
      end if;
      pag_htm.PR_COLUMNA(v_nro_documento); -- agrego la columna del nro de cuenta
    pag_htm.PR_FILA('N'); -- CIERRO LA FILA
  
 if v_des_tra_padre='TRANSFERENCIA INTERBANCARIA' then 
    pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Nombre Beneficiario:',120,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(v_snp_nom_beneficiario); -- agrego la columna del nro de cuenta
    pag_htm.PR_FILA('N'); -- CIERRO LA FILA

    pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Cuenta Beneficiario:',120,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(v_snp_nro_cta_beneficiario); -- agrego la columna del nro de cuenta
    pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Swift Entidad Beneficiaria:',120,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(v_snp_cod_swi_pte_beneficiario); -- agrego la columna del nro de cuenta
    pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    
    --to_char(reg.monto,'999,999,999,999.99')
    pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Monto:',100,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(v_snp_cod_moneda||'  '|| to_char(v_snp_monto,'999,999,999,999.99')); -- agrego la columna del nro de cuenta
    pag_htm.PR_FILA('N'); -- CIERRO LA FILA         
 end if;  
    pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Fecha:',120,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(to_char(p_fecha,'dd/mm/yyyy')); -- agrego la columna del nro de cuenta
    pag_htm.PR_FILA('N'); -- CIERRO LA FILA

    if v_hora is not null then
       pag_htm.PR_FILA('S'); -- ABRO LA FILA
         pag_htm.PR_COLUMNA('Hora:',120,'left','S'); -- agrego la columna etiqueta
         pag_htm.PR_COLUMNA(v_hora); -- agrego la columna del nro de cuenta
       pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    end if ;
  
    pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Oficina:',120,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(fue_obt_des_oficina(v_ofi_origen)); -- agrego la columna del nro de cuenta
    pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    
    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Monto '||v_tip_mov||':',120,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(v_cod_moneda,30,'left');
      pag_htm.PR_COLUMNA(to_char(v_monto,'999,999,999,999.99'));
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    
    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Concepto:',120,'left','S'); -- agrego la columna etiqueta
                       if v_cod_tra_padre=303 then
                          if v_cod_transaccion = 196 then
                            v_concepto:='CARGO POR TRANSFERENCIA OTROS BANCOS';
                          end if;
                          if v_cod_transaccion = 517 then
                            v_concepto:='IVA S/COMISIONES TRANS. A OTROS BANCOS';
                          end if;

                       end if;      
      pag_htm.PR_COLUMNA(pag_htm.FU_CON_HTML(v_concepto)); -- agrego la columna del nro de cuenta
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      
      if v_cod_banco is not null then
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('Banco:',120,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA(v_cod_banco); -- agrego la columna del nro de cuenta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      end if;
      if v_nro_caja is not null then
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('Nro. Caja:',120,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA(v_nro_caja); -- agrego la columna del nro de cuenta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      end if;
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal
   
    if p_tipo = 'I' then -- Transferencia Interbancaria
       pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA 
       pag_htm.PR_FILA('S'); -- ABRO LA FILA
       pag_htm.PR_COLUMNA('Tipo Valor:',120,'left','S'); -- agrego la columna etiqueta
       pag_htm.PR_COLUMNA(v_tip_mt); -- agrego la columna del nro de cuenta
       pag_htm.PR_FILA('N'); -- CIERRO LA FILA
       --
       pag_htm.PR_FILA('S'); -- ABRO LA FILA
       pag_htm.PR_COLUMNA('Estado:',120,'left','S'); -- agrego la columna etiqueta
       pag_htm.PR_COLUMNA(v_estado); -- agrego la columna del nro de cuenta
       pag_htm.PR_FILA('N'); -- CIERRO LA FILA
       --
       pag_htm.PR_FILA('S'); -- ABRO LA FILA
       pag_htm.PR_COLUMNA('Situación:',120,'left','S'); -- agrego la columna etiqueta
       pag_htm.PR_COLUMNA(v_situacion); -- agrego la columna del nro de cuenta
       pag_htm.PR_FILA('N'); -- CIERRO LA FILA
       --
       pag_htm.PR_FILA('S'); -- ABRO LA FILA
       pag_htm.PR_COLUMNA('Detalle del Mensaje:',120,'left','S'); -- agrego la columna etiqueta
       pag_htm.PR_COLUMNA(replace(v_msj_swift,chr(10),'</td></tr><tr><td></td><td class="negro">')); -- agrego la columna del nro de cuenta
       pag_htm.PR_FILA('N'); -- CIERRO LA FILA
       pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
       pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal   
    else
    --detalles del movimiento
        v_primero := true;
        pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA        
        for reg in detalles loop
          if lf_cta_relacionadas(v_nro_cuenta, reg.nro_cuenta) = 'S' then 
             --
              v_cont := v_cont + 1;
              if v_cont > 90 then
                 v_retorno := v_retorno||pag_htm.v_texto;
                 pag_htm.v_texto := null;
                 v_cont    := 0;
              end if;
              --
              if v_primero then
                pag_htm.PR_FILA('S'); -- ABRO LA FILA
                  pag_htm.PR_COLUMNA('DETALLES DEL MOVIMIENTO',NULL,'center','S'); -- agrego la columna etiqueta
                  pag_htm.PR_FILA('N'); -- CIERRO LA FILA
                pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
                pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal   
                
                pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
                  pag_htm.PR_FILA('S'); -- ABRO LA FILA
                  pag_htm.PR_COLUMNA('Descripci&oacute;n',300,'left','S'); -- agrego la columna etiqueta
                  pag_htm.PR_COLUMNA('Cuenta',133,'left','S'); -- agrego la columna etiqueta
                  if v_cod_tra_padre in (360,361,362,359) then --préstamos
                     pag_htm.PR_COLUMNA('Cuota',20,'center','S');
                     pag_htm.PR_COLUMNA('Fec. Vto.',90,'center','S');
                  else
                     pag_htm.PR_COLUMNA(null,30,'center','S');
                  end if;
                  pag_htm.PR_COLUMNA('&nbsp;&nbsp;Mon.',15,'left','S'); -- agrego la columna 
                  if v_cod_tra_padre in (360,361,362,359) then --préstamos
                     pag_htm.PR_COLUMNA('Monto',100,'right','S'); -- agrego la columna
                  else 
                     pag_htm.PR_COLUMNA('Monto',180,'right','S'); -- agrego la columna
                  end if;   
                  pag_htm.PR_FILA('N'); -- CIERRO LA FILA
                  v_primero := false;
              end if; 
              if v_tiene_factura = 'N' then
                if pab_iva.FU_MOV_CON_IVA(reg.modulo, reg.modalidad, reg.cod_transaccion) = 'S' then
                   v_tiene_factura := 'S';
                end if;   
              end if;             
              pag_htm.PR_FILA('S'); -- ABRO LA FILA
              v_det_descripcion := fue_obt_titulo(reg.descripcion);
              if v_det_descripcion = 'Cobro de Prestamos por Caja' and v_nro_caja is null then
                 v_det_descripcion := 'Cobro de Pr&eacute;stamos por BBVA Net'; -- agrego la columna
              end if;
              pag_htm.PR_COLUMNA(v_det_descripcion,300,'left'); -- agrego la columna                            
              if reg.cod_modulo = 5 then --tarjeta
                 pag_htm.PR_COLUMNA(fut_for_tarjeta(reg.nro_cuenta),130,'left'); -- agrego la columna 
              else
                 pag_htm.PR_COLUMNA(reg.cta_formateada,133,'left'); -- agrego la columna 
              end if;
              if v_cod_tra_padre in (360,361,362,359) then --préstamos
                pag_htm.PR_COLUMNA(reg.nro_documento3,20,'center');
                pag_htm.PR_COLUMNA(reg.fec_vencimiento,90,'center');
              else
                pag_htm.PR_COLUMNA(null,30,'center','S');
              end if;
              pag_htm.PR_COLUMNA('&nbsp;&nbsp;'||reg.cod_moneda,15,'left'); -- agrego la columna 
              if v_cod_tra_padre in (360,361,362,359) then --préstamos
                 pag_htm.PR_COLUMNA(to_char(reg.monto,'999,999,999,999.99'),100,'right'); -- agrego la columna
              else
                 pag_htm.PR_COLUMNA(to_char(reg.monto,'999,999,999,999.99'),180,'right'); -- agrego la columna
              end if;               
              pag_htm.PR_FILA('N'); -- CIERRO LA FILA
          end if;
        end loop;
                
        pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA   
     end if ;
     if not v_primero then 
        pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal 
     end if;
     pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      if p_tipo = 'I' then
         pag_htm.pr_columna('Este comprobante es una Copia.',630,'center');
      else
         pag_htm.pr_columna('Este comprobante es una Copia. No requiere firmas autorizadas',630,'center');
      end if ;
      pag_htm.PR_TABLA('N');
      if v_des_tra_padre='TRANSFERENCIA INTERBANCARIA' then 
      pag_htm.pr_texto('<hr width=630>');
      pag_htm.PR_TABLA('S');
      pag_htm.PR_FILA('S');

       pag_htm.PR_FILA('S');
       
       pag_htm.pr_columna('La acreditaci&oacute;n del importe transferido en la cuenta del beneficiario, ser&aacute; exclusiva responsabilidad del Banco Destinatario de los fondos.',630,'left');
       pag_htm.PR_FILA('N');
      end if;
     pag_htm.PR_TABLA('N');
  end if;
  v_retorno := v_retorno || pag_htm.v_texto;
  return v_tiene_factura||v_retorno;
end FUW_IMP_COMPROBANTE;
/

