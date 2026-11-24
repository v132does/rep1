create or replace function it.FUJ_IMP_COMPROBANTE_221
  (p_nro_operacion in number,
   p_cod_oficina   in number,
   p_nro_caja      in number,
   p_cod_mad_padre IN NUMBER DEFAULT NULL)
 return varchar2 is
  --comprimido 40 de ancho
  v_ancho     	 	 number(3) := 40; -- ancho del reporte
  v_resultado 		 varchar2(4000) := null;
  v_linea     		 varchar2(200);
  v_fecha          date := SYSDATE;
  v_hora           varchar2(8) := to_char(sysdate,'hh24:mi:ss');
  v_col_antes      number;
  --
  v_nro_impresion number(10);
  v_tip_operacion varchar2(100);
  v_cod_tip_ope_cambio  varchar2(6);
  v_des_tip_operacion varchar2(100);
  v_nom_usuario varchar2(100);
  v_cod_ope_bcp varchar2(6);
  v_des_ope_bcp varchar2(100);
  v_referencia varchar2(20);
  v_cod_moneda varchar2(4);
  v_monto number(18,2);
  v_cotizacion number(18,4);
  v_mto_equ_local number(18);
  v_cta_cambios varchar2(20);
  v_nro_documento varchar2(20);
  v_nom_persona varchar2(200);
  v_des_moneda  varchar2(100);
  v_importe number;
  v_una_vez varchar2(1) :='S';
  v_cod_usuario varchar2(10);
  v_sigla ge_bancos.sigla%type;
  v_nro_documento3 ge_movimientos.nro_documento3%type;
  v_nro_cuenta     ge_movimientos.nro_cuenta%type;
  v_cta_formateada varchar2(20);
  v_gastos number:=0;
  v_dir_beneficiario varchar2(200);
  v_mad_operacion lc_transferencias.cod_modalidad%type;
  v_nro_ref_externa lc_transferencias.nro_ref_externa%type;
  --cursor de movimientos de la operación
  cursor mov is
  select a.monto monto, b.descripcion des_transaccion, a.cod_mad_padre modalidad,
         decode(nvl(a.cod_tip_ope_cambio,'X'),'X',a.cod_moneda) moneda,
         a.cod_tip_ope_cambio operacion, 
         decode(a.cod_transaccion,606,c.descripcion||' NTRO. BANCO',
           decode(c.tip_valor,'C',c.descripcion||' OTROS BANCOS',c.descripcion)) des_operacion,
         rownum, nro_secuencia, g.descripcion des_mon_vta, cotizacion,
         a.cod_transaccion, a.cod_banco, a.nro_documento, a.nro_cuenta, a.mto_equ_local
    from ba_monedas g,lc_tip_operaciones c, ge_transacciones b, ge_movimientos a
   where a.nro_documento = p_nro_operacion
     and a.reversado = 'N'
     and a.cod_mod_padre = 7
     and a.nro_secuencia > 1 --formas de cobro/pago
     and a.cod_transaccion not in (760,401)
     and b.cod_transaccion = a.cod_transaccion
     and b.cod_modulo = a.cod_modulo
     and b.cod_modalidad = a.cod_modalidad
     and g.cod_moneda = a.cod_moneda
     and monto >0
     and c.cod_tip_operacion (+)= a.cod_tip_ope_cambio;
--     order by nro_secuencia;

--detalle forma de pago si es cheque gcia
cursor cheque is
select b.descripcion tip_operacion, a.nro_documento,--cheque
       a.monto, a.cod_banco, d.descripcion banco, c.beneficiario, d.sigla
  from ge_bancos d, cc_che_ger_emitidos c,
       lc_tip_operaciones b, ge_movimientos a
 where a.cod_mod_padre = 7
       and a.reversado = 'N'
       and a.fecha = v_fecha
       and a.hora = v_hora
       and a.cod_usuario = v_cod_usuario
       and a.cod_tip_ope_cambio = b.cod_tip_operacion
       and a.nro_secuencia > 1 --formas de pago
       and a.monto > 0
       and a.val_tasa is null --para no traer gastos
       and a.cod_transaccion not in (760,401)
       and a.cod_tip_ope_cambio in(2)--pago en cheque gcia
       and d.cod_banco(+) = a.cod_banco
       and c.nro_cuenta(+) = a.nro_cuenta
       and c.nro_cheque(+) = a.nro_documento
order by a.cod_tip_ope_cambio,nro_secuencia;
--detalle de cobro
cursor detalle is
select sigla, nro_cheque, monto
  from ge_bancos d, gv_cheques_det c
 where d.cod_banco = c.cod_banco
 and c.nro_boleta = p_nro_operacion
 and c.nro_cuenta is null;--no se guarda la cuenta en el detalle de cheques

begin
  -- seteo la oficina
  pag_imp.pr_set_oficina(p_cod_oficina);
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
  --imprimir nro de impresión, x ahora no se enumeran
  v_nro_impresion := 0;
  Begin
    Select nvl(count(*),0) 
      into v_nro_impresion
      from cj_movimientos
     where cod_tra_padre = 110
       and cod_mod_padre = 9
       and cod_mad_padre = 91
       and nro_documento = p_nro_operacion;
  End;

  -- datos del registro principal, nro_secuencia 1
  begin
    select fug_obt_des_modal(a.cod_mod_padre,a.cod_mad_padre) tip_operacion, 
           a.cod_tip_ope_cambio, b.descripcion des_tip_operacion, a.nro_cuenta,
           a.fecha, a.hora, a.cod_usuario, fue_obt_nom_usuario(a.cod_usuario) usuario,
           a.cod_bco_central cod_ope_bcp, c.descripcion des_ope_bcp,
           a.cod_ref_cambio||'/'||a.nro_documento2 referencia, b.cod_modalidad,
           a.cod_moneda, a.monto, a.cotizacion, a.mto_equ_local,
           e.cta_cambios, x.nro_doc_beneficiario, x.nom_beneficiario, x.dir_beneficiario,
           g.descripcion, h.sigla, a.nro_documento3, /*cpra cheq/vta transf*/ x.nro_ref_externa
      into v_tip_operacion,  v_cod_tip_ope_cambio, v_des_tip_operacion, v_nro_cuenta,
           v_fecha, v_hora, v_cod_usuario,
           v_nom_usuario,  v_cod_ope_bcp,  v_des_ope_bcp,  v_referencia, v_mad_operacion,
           v_cod_moneda,  v_monto,  v_cotizacion,  v_mto_equ_local,
           v_cta_cambios,  v_nro_documento,  v_nom_persona, v_dir_beneficiario,
           v_des_moneda, v_sigla, v_nro_documento3, v_nro_ref_externa
      from lc_transferencias x, ge_bancos h, ba_monedas g, ba_personas f, lc_tip_ope_bcp c, lc_tip_operaciones b, ge_movimientos a,
           (select nro_cuenta cta_cambios,
                   to_char(nro_documento2) cod_persona,
                   decode(nvl(nro_documento2,0),0,concepto,fue_obt_nom_persona(nro_documento2)) nom_persona,
                   referencia nro_documento
              from ge_movimientos
             where nro_documento = p_nro_operacion
               and reversado = 'N'
               and cod_mod_padre = 7
               and cod_mad_padre = p_cod_mad_padre
               and cod_transaccion = 760) e
     where a.nro_documento = p_nro_operacion
       and a.reversado = 'N'
       and a.cod_mod_padre = 7
       and a.cod_mad_padre = p_cod_mad_padre
       and a.nro_secuencia = 1
       and b.cod_tip_operacion = a.cod_tip_ope_cambio
       and c.cod_tip_ope_bcp = a.cod_bco_central
       and f.cod_persona(+) = e.cod_persona
       and h.cod_banco (+) = a.cod_banco
       and g.cod_moneda = a.cod_moneda
       and x.cod_tip_referencia = a.cod_ref_cambio
       and x.nro_referencia = a.nro_documento2;
  exception
    when no_data_found then
       raise_application_error(-20000,'Operación inexistente');
  end;
  --si es arbitraje o canje traer la secuencia 2
  /*if v_mad_operacion in (73, 74) then
     begin
        select a.cod_moneda, a.monto, a.cotizacion, a.mto_equ_local
          into v_mon_vta, v_mto_vta, v_cot_vta, v_mto_equ_vta
          from ge_movimientos
         where a.fecha = v_fecha
           and a.hora = v_hora
           and a.cod_usuario = v_cod_usuario
           and a.nro_secuencia = 2;
  end if;*/
  
  pag_imp.pr_imp_cab_centrada(v_resultado,'PAGO DE TRANSFERENCIAS',NULL,1);

  --v_linea := 'IMPRESION: '||v_nro_impresion;
  --pag_imp.pr_imp_linea(v_resultado, v_linea, 0, 0, 'S');

  -- imprimo la fecha y hora
  v_linea := 'Fecha: '||to_char(v_fecha,'dd/mm/yyyy')||'               '||v_hora;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 2);
  -- Imprimo datos del cajero --ver si el usuario del movimiento = al del mov. de caja
  v_nom_usuario :=fue_obt_nom_usuario(user);
  if fug_obt_tip_implementacion = 1 then
    v_linea := 'Caja: '||rpad(p_nro_caja,4,' ');--||lpad(v_nom_usuario,30,' ');
  else
    v_linea := 'Caja: '||rpad(p_nro_caja,4,' ')||lpad(v_nom_usuario,30,' ');
  end if;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);

  --imprimo nro operación
  v_linea := 'Oper.Nro: '||rpad(p_nro_operacion,8,' ')||lpad('Ref.: '||v_referencia,22,' ');
  pag_imp.pr_imp_linea(v_resultado,v_linea,1);

  if v_nro_impresion = 0 then
    v_linea := lpad('Original',40,' ');
  else  
    v_linea := lpad('Copia Nro.: ',35,' ')||lpad(v_nro_impresion,5,' ');
  end if;  
  pag_imp.pr_imp_linea(v_resultado,v_linea,1);
  
  pag_imp.pr_imp_linea(v_resultado,'Tipo: '||v_cod_tip_ope_cambio||' '||substr(v_des_tip_operacion,1,30),2);

  v_linea := 'Cod.BCP:'||v_cod_ope_bcp||' '||v_des_ope_bcp;
  v_linea := substr(v_linea,1,40);
  pag_imp.pr_imp_linea(v_resultado,v_linea,1);

  pag_imp.PR_IMP_LINEA(v_resultado,'Nro.Ref.Externa: '||v_nro_ref_externa,2);

  -- cliente
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),2);
  pag_imp.PR_IMP_LINEA(v_resultado,'Beneficiario: ',1);
  pag_imp.PR_IMP_LINEA(v_resultado,'Nro.Doc. '||v_nro_documento,1);
  pag_imp.PR_IMP_LINEA(v_resultado,substr(v_nom_persona,1,40),1);
  pag_imp.PR_IMP_LINEA(v_resultado,substr(v_dir_beneficiario,1,40),1);
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),2);


  --imprimir detalle de compra de cheque y venta de transferencias
  /*if v_cod_tip_ope_cambio = '18' then
     if v_sigla is not null and v_nro_documento3 is not null then
        v_linea := 'BANCO '||v_sigla||'. CHEQUE '||substr(v_nro_documento3,1,15);
        v_linea := substr(v_linea,1,40);
        pag_imp.pr_imp_linea(v_resultado,v_linea,2);
     end if;
  elsif v_cod_tip_ope_cambio = '29' and fug_obt_tip_implementacion <>1 then
     v_linea := 'BANCO '||v_sigla||'. NOTA TRANSF. '||substr(v_nro_documento3,1,15);
     v_linea := substr(v_linea,1,40);
     pag_imp.pr_imp_linea(v_resultado,v_linea,2);
  end if;*/
--  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
  pag_imp.pr_imp_linea(v_resultado,rpad(initcap(v_des_moneda),24,' ')||' '||lpad(to_char(v_monto,'999,999,999.99'),15,' '),1);
  pag_imp.pr_imp_linea(v_resultado,'Cotizacion       '||lpad(to_char(v_cotizacion,'99,999.9999'),23,' '),1);
  pag_imp.pr_imp_linea(v_resultado,'Guaranies        '||lpad(to_char(v_mto_equ_local,'999,999,999,999.99'),23,' '),1);

	--Detalle de Impresión
  --primero los gastos
  for reg in mov loop
    if reg.operacion is null then
      --gastos
      if v_gastos = 0 then--reg.rownum = 1 then --una sola vez
       --if reg.modalidad in (71,73,74 then --compra, arb, canje
         pag_imp.pr_imp_linea(v_resultado,'Gastos (-)',2);
         v_gastos:=1;
       --end if;
       pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
      end if;
      v_linea :=substr(reg.des_transaccion,1,20);
      --v_col_antes := v_ancho - length(v_linea)-30;
      --el imp x transferencia en compra esta en moneda extranjera
      if reg.cod_transaccion = 572 and reg.modalidad = 71 then
         v_linea := rpad(v_linea,20,' ')||lpad(to_char(reg.mto_equ_local,'999,999,999,999.99'),20,' ');
      else
         v_linea := rpad(v_linea,20,' ')||lpad(to_char(reg.monto,'999,999,999,999.99'),20,' ');
      end if;
      pag_imp.pr_imp_linea(v_resultado,v_linea,1);
    end if; 
  end loop;

  --forma de pago o cobro si es venta
  for reg in mov loop
    if reg.operacion is not null then--else
      --forma de pago/cobro
      if v_una_vez ='S' then--para q imprima una sola vez
         --if reg.modalidad = 71 then --compra
           pag_imp.pr_imp_linea(v_resultado,'Forma de Pago',2);
         --else
           --pag_imp.pr_imp_linea(v_resultado,'Forma de Cobro',2);
         --end if;
         pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
         v_una_vez :='N';
      end if;
      --if reg.operacion <> 7 then-- q no sea cobro cheq
        --si es contra cuenta, acortar la descripción y mostrar el nro. de cuenta
        if v_mad_operacion in (73, 74) then
           if reg.nro_secuencia = 2 then--venta
             pag_imp.pr_imp_linea(v_resultado,rpad(initcap(reg.des_mon_vta),24,' ')||' '||lpad(to_char(reg.monto,'999,999,999.99'),15,' '),1);
             pag_imp.pr_imp_linea(v_resultado,'Cotizacion       '||lpad(to_char(reg.cotizacion,'99,999.9999'),23,' '),1);
             pag_imp.pr_imp_linea(v_resultado,'Guaranies        '||lpad(to_char(reg.mto_equ_local,'999,999,999,999.99'),23,' '),1);
           end if;
        else
          if reg.operacion = 3 then --pago crédito en cta
             v_linea := 'CRED.CTA '||reg.nro_cuenta;
          else
            v_linea := substr(reg.des_operacion,1,20);
          end if;
          v_linea := rpad(v_linea,20,' ')||lpad(to_char(reg.monto,'999,999,999,999.99'),20,' ');
          pag_imp.pr_imp_linea(v_resultado,v_linea,1);
        end if;
      --end if;
    end if;
  end loop;

   --detalle de cheque (gcia) pagado si hubiera, SÓLO si no es compra de cheque puede imprimir detalle cheque
  /*if v_cod_tip_ope_cambio <> '18' then
    for reg1 in cheque loop
       if v_una_vez ='S' then--para q imprima una sola vez
          pag_imp.pr_imp_linea(v_resultado,'Forma de Pago',2);
          pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
          v_una_vez :='N';
       end if;
       v_linea := 'CHEQ.'||reg1.sigla||' '||substr(reg1.nro_documento,1,15);
       v_linea := rpad(v_linea,20,' ')||lpad(to_char(reg1.monto,'999,999,999,999.99'),20,' ');
       pag_imp.pr_imp_linea(v_resultado,v_linea,1);
    end loop;
  end if;*/
  
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),11);

  --firma del cliente
  pag_imp.PR_IMP_LINEA(v_resultado,lpad(' ',21,'.'),4,20);
  pag_imp.PR_IMP_LINEA(v_resultado,'Recibi conforme.',2,23);
  pag_imp.PR_IMP_LINEA(v_resultado,'C.I. '||v_nro_documento,2,23);

  --comentario x tipo de implementacion
  if fug_obt_tip_implementacion = 3 then
     v_linea:= 'El cumplimiento  de la  obligacion  por';
     pag_imp.PR_IMP_LINEA(v_resultado,v_linea,2);
     v_linea:= 'cada  parte en  esta  transaccion  esta';
     pag_imp.PR_IMP_LINEA(v_resultado,v_linea,1);
     v_linea:= 'sujeta  a   las  leyes,   regulaciones,';
     pag_imp.PR_IMP_LINEA(v_resultado,v_linea,1);
     v_linea:= 'decretos y  disposiciones del Gobierno.';
     pag_imp.PR_IMP_LINEA(v_resultado,v_linea,1);
  end if;

  -- imprimo el pie
  pag_imp.pr_imp_pie(v_resultado, 5);   -- linea antes

  v_linea := null;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 10, 0);

  return(v_resultado);

end FUJ_IMP_COMPROBANTE_221;
/

