create or replace function it.FUJ_IMP_COMPROBANTE_243
  (p_nro_operacion in number,
   p_cod_oficina   in number,
   p_nro_caja      in NUMBER,
   p_cod_mad_padre IN NUMBER DEFAULT NULL)
 return LONG is
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
  v_existe number;
  v_gastos number:=0;
  v_imp_cheque varchar2(1) :='N';
  v_cta_formateada varchar2(20);
  --cursor de movimientos de la operacion
  cursor mov is
     select fug_obt_des_modal(a.cod_mod_padre,a.cod_mad_padre) tip_operacion,
           a.cod_tip_ope_cambio, b.descripcion des_tip_operacion, a.nro_cuenta,
           a.fecha, a.hora, a.cod_usuario, fue_obt_nom_usuario(a.cod_usuario) usuario,
           a.cod_bco_central cod_ope_bcp, c.descripcion des_ope_bcp,
           a.cod_ref_cambio||'/'||a.nro_documento2 referencia,
           a.cod_moneda, a.monto, a.cotizacion, a.mto_equ_local,
           e.cta_cambios, decode(nvl(f.nro_documento,'X'),'X',e.nro_documento,f.nro_documento) doc_persona, e.nom_persona,
           g.descripcion des_moneda, h.sigla, a.nro_documento3, --cpra cheq/vta transf
           a.nro_secuencia
      from ge_bancos h, ba_monedas g, ba_personas f, lc_tip_ope_bcp c, lc_tip_operaciones b, ge_movimientos a,
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
       and a.cod_mad_padre in (73,74)
       and a.nro_secuencia in (1,2)
       and a.cod_mad_padre = p_cod_mad_padre
       and b.cod_tip_operacion = a.cod_tip_ope_cambio
       and c.cod_tip_ope_bcp = a.cod_bco_central
       and f.cod_persona(+) = e.cod_persona
       and h.cod_banco (+) = a.cod_banco
       and g.cod_moneda = a.cod_moneda
  order by a.nro_secuencia;

  cursor gastos is
    select a.monto monto, b.descripcion des_transaccion, a.cod_mad_padre modalidad,
           decode(nvl(a.cod_tip_ope_cambio,'X'),'X',a.cod_moneda) moneda,
           a.cod_tip_ope_cambio operacion, 
           decode(a.cod_transaccion,606,c.descripcion||' NTRO. BANCO',
             decode(c.tip_valor,'C',c.descripcion||' OTROS BANCOS',c.descripcion)) des_operacion,
           rownum,
           a.cod_transaccion, a.cod_banco, a.nro_documento, a.nro_cuenta, a.mto_equ_local
      from lc_tip_operaciones c, ge_transacciones b, ge_movimientos a
     where a.nro_documento = p_nro_operacion
       and a.reversado = 'N'
       and a.cod_mod_padre = 7
       and a.cod_mad_padre in (73,74)
       and a.nro_secuencia > 2
       and a.cod_transaccion not in (760,401)
       and b.cod_transaccion = a.cod_transaccion
       and b.cod_modulo = a.cod_modulo
       and b.cod_modalidad = a.cod_modalidad
       and monto >0
       and c.cod_tip_operacion (+)= a.cod_tip_ope_cambio
     order by a.nro_secuencia;


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
  from ge_bancos d, ge_cheques_det c
 where d.cod_banco = c.cod_banco
 and c.nro_documento = p_nro_operacion
 and c.nro_cuenta is null;--no se guarda la cuenta en el detalle de cheques

begin
  -- seteo la oficina
  pag_imp.pr_set_oficina(p_cod_oficina);
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
  --imprimir nro de impresion, x ahora no se enumeran
  v_nro_impresion := 0;
  Begin
    Select nvl(count(*),0) + 1
      into v_nro_impresion
      from cj_movimientos
     where cod_tra_padre = 110
       and cod_mod_padre = 9
       and cod_mad_padre = 91
       and nro_documento = p_nro_operacion;
  End;
  if v_nro_impresion =1 then--si fue con autorizacion es la 1er impresion no es reimpresion
    Select nvl(count(*),0)
      into v_existe
      from ge_movimientos b, ge_aut_pedidos a
     where b.fecha = a.fecha
       and b.hora = a.hora
       and b.cod_usuario = a.cod_usuario
       and nro_documento = p_nro_operacion;
       if v_existe > 0 then
       	  v_nro_impresion := 1;
       end if;
  end if;
  -- datos del registro principal, nro_secuencia 1
/*  begin
    select fug_obt_des_modal(a.cod_mod_padre,a.cod_mad_padre) tip_operacion,
           a.cod_tip_ope_cambio, b.descripcion des_tip_operacion,
           a.fecha, a.hora, a.cod_usuario, fue_obt_nom_usuario(a.cod_usuario) usuario,
           a.cod_bco_central cod_ope_bcp, c.descripcion des_ope_bcp,
           a.cod_ref_cambio||'/'||a.nro_documento2 referencia,
           a.cod_moneda, a.monto, a.cotizacion, a.mto_equ_local,
           e.cta_cambios, decode(nvl(f.nro_documento,'X'),'X',e.nro_documento,f.nro_documento), e.nom_persona,
           g.descripcion, h.sigla, a.nro_documento3 --cpra cheq/vta transf
      into v_tip_operacion,  v_cod_tip_ope_cambio,  v_des_tip_operacion,
           v_fecha, v_hora, v_cod_usuario,
           v_nom_usuario,  v_cod_ope_bcp,  v_des_ope_bcp,  v_referencia,
           v_cod_moneda,  v_monto,  v_cotizacion,  v_mto_equ_local,
           v_cta_cambios,  v_nro_documento,  v_nom_persona,
           v_des_moneda, v_sigla, v_nro_documento3
      from ge_bancos h, ba_monedas g, ba_personas f, lc_tip_ope_bcp c, lc_tip_operaciones b, ge_movimientos a,
           (select nro_cuenta cta_cambios,
                   to_char(nro_documento2) cod_persona,
                   decode(nvl(nro_documento2,0),0,concepto,fue_obt_nom_persona(nro_documento2)) nom_persona,
                   referencia nro_documento
              from ge_movimientos
             where nro_documento = p_nro_operacion
               and reversado = 'N'
               and cod_mod_padre = 7
               and cod_transaccion = 760) e
     where a.nro_documento = p_nro_operacion
       and a.reversado = 'N'
       and a.cod_mod_padre = 7
       and a.nro_secuencia = 1
       and b.cod_tip_operacion = a.cod_tip_ope_cambio
       and c.cod_tip_ope_bcp = a.cod_bco_central
       and f.cod_persona(+) = e.cod_persona
       and h.cod_banco (+) = a.cod_banco
       and g.cod_moneda = a.cod_moneda;
  exception
    when no_data_found then
       raise_application_error(-20000,'Operacion inexistente');
  end;*/
  
  for reg in mov loop
    if reg.nro_secuencia = 1 then -- compra
      
        pag_imp.pr_imp_cab_centrada(v_resultado,'COMPROBANTE DE VENTA','*** '||reg.tip_operacion||' ***',1);
      
        v_linea := 'IMPRESION: '||v_nro_impresion;
        pag_imp.pr_imp_linea(v_resultado, v_linea, 0, 0, 'S');
      
        -- imprimo la fecha y hora
        v_linea := 'Fecha: '||to_char(v_fecha,'dd/mm/yyyy')||'               '||v_hora;
        pag_imp.pr_imp_linea(v_resultado, v_linea, 2);
        -- Imprimo datos del cajero --ver si el usuario del movimiento = al del mov. de caja
        v_nom_usuario :=fue_obt_nom_usuario(user);
        v_linea := 'Caja: '||rpad(p_nro_caja,4,' ')||lpad(v_nom_usuario,30,' ');
        pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
        
        --imprimo nro operacion
        v_linea := 'Comp.Nro: '||rpad(p_nro_operacion,8,' ')||lpad('Ref.: '||reg.referencia,22,' ');
        pag_imp.pr_imp_linea(v_resultado,v_linea,1);

        --datos de la operacion
        pag_imp.pr_imp_linea(v_resultado,'Tipo: '||reg.cod_tip_ope_cambio||' '||substr(reg.des_tip_operacion,1,30),2);
      
        v_linea := 'Cod.BCP:'||reg.cod_ope_bcp||' '||reg.des_ope_bcp;
        v_linea := substr(v_linea,1,40);
        pag_imp.pr_imp_linea(v_resultado,v_linea,1);

        --imprimir detalle de compra de cheque y venta de transferencias
        if reg.cod_tip_ope_cambio in ('57','87') then
           if reg.sigla is not null and reg.nro_documento3 is not null then
              v_linea := 'BANCO '||reg.sigla||'. CHEQUE '||substr(reg.nro_documento3,1,15);
              v_linea := substr(v_linea,1,40);
              pag_imp.pr_imp_linea(v_resultado,v_linea,2);
           end if;
        /*elsif v_cod_tip_ope_cambio = '29' then
           if v_sigla is not null and v_nro_documento3 is not null then
              v_linea := 'BANCO '||v_sigla||'. NOTA TRANSF. '||substr(v_nro_documento3,1,15);
              v_linea := substr(v_linea,1,40);
              pag_imp.pr_imp_linea(v_resultado,v_linea,2);
           end if;*/
        end if;

        if reg.nro_cuenta is not null then --es compra o venta de cuenta cliente
          pag_cta.PR_OBT_CUENTA(reg.nro_cuenta);
          v_cta_formateada := fug_cta_formateada(pag_cta.g_ctas.cod_modulo,pag_cta.G_CTAS.cod_modalidad,
                              pag_cta.G_CTAS.cod_oficina,reg.nro_cuenta,pag_cta.G_CTAS.cod_moneda);
       	  IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
            raise_application_error(-20005,'Recup.Cta '||pag_cta.fu_obt_msj_error());
          END IF;
       
          v_linea := 'Cuenta: '||v_cta_formateada;
          v_linea := substr(v_linea,1,40);
          pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita                    
          pag_imp.pr_imp_linea(v_resultado,v_linea,1);
          pag_imp.pr_negrita(v_resultado,'N'); -- Apaga negrita
          v_linea := 'Nombre: '||pag_cta.G_CTAS.denominacion;
          v_linea := substr(v_linea,1,40);
          pag_imp.pr_imp_linea(v_resultado,v_linea,1);
        end if;

        pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
        pag_imp.pr_imp_linea(v_resultado,rpad(initcap(reg.des_moneda),24,' ')||' '||lpad(to_char(reg.monto,'999,999,999.99'),15,' '),1);
        pag_imp.pr_imp_linea(v_resultado,'Cotizacion       '||lpad(to_char(reg.cotizacion,'999,999.99'),23,' '),1);
        pag_imp.pr_imp_linea(v_resultado,'Guaranies        '||lpad(to_char(reg.mto_equ_local,'999,999,999,999.99'),23,' '),1);

    else --venta
        --datos de la operacion
        pag_imp.pr_imp_linea(v_resultado,'Tipo: '||reg.cod_tip_ope_cambio||' '||substr(reg.des_tip_operacion,1,30),2);

        v_linea := 'Cod.BCP:'||reg.cod_ope_bcp||' '||reg.des_ope_bcp;
        v_linea := substr(v_linea,1,40);
        pag_imp.pr_imp_linea(v_resultado,v_linea,1);

        if reg.nro_cuenta is not null then --es compra o venta de cuenta cliente
          pag_cta.PR_OBT_CUENTA(reg.nro_cuenta);
          v_cta_formateada := fug_cta_formateada(pag_cta.g_ctas.cod_modulo,pag_cta.G_CTAS.cod_modalidad,
                              pag_cta.G_CTAS.cod_oficina,reg.nro_cuenta,pag_cta.G_CTAS.cod_moneda);
       	  IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
            raise_application_error(-20005,'Recup.Cta '||pag_cta.fu_obt_msj_error());
          END IF;
       
          v_linea := 'Cuenta: '||v_cta_formateada;
          v_linea := substr(v_linea,1,40);
          pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita                    
          pag_imp.pr_imp_linea(v_resultado,v_linea,1);
          pag_imp.pr_negrita(v_resultado,'N'); -- Apaga negrita
          v_linea := 'Nombre: '||pag_cta.G_CTAS.denominacion;
          v_linea := substr(v_linea,1,40);
          pag_imp.pr_imp_linea(v_resultado,v_linea,1);
        end if;

        pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
        pag_imp.pr_imp_linea(v_resultado,rpad(initcap(reg.des_moneda),24,' ')||' '||lpad(to_char(reg.monto,'999,999,999.99'),15,' '),1);
        pag_imp.pr_imp_linea(v_resultado,'Cotizacion       '||lpad(to_char(reg.cotizacion,'999,999.99'),23,' '),1);
        pag_imp.pr_imp_linea(v_resultado,'Guaranies        '||lpad(to_char(reg.mto_equ_local,'999,999,999,999.99'),23,' '),1);
    
        -- cliente
        pag_imp.PR_IMP_LINEA(v_resultado,'Nro.Doc: '||reg.doc_persona,3);
        pag_imp.PR_IMP_LINEA(v_resultado,substr(reg.nom_persona,1,40),1);
        pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),2);
        pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),11);

    end if;

	--Detalle de Impresión
  --primero los gastos
  if v_una_vez = 'S' then
    for reg in gastos loop
      if reg.operacion is null then
        --gastos, sólo a la compra se le imputa
        if v_gastos = 0 then--reg.rownum = 1 then --una sola vez
           if reg.modalidad in (73,74) then --compra
              pag_imp.pr_imp_linea(v_resultado,'Gastos (-)',2);
              v_gastos:=1;
           /*else --venta
              pag_imp.pr_imp_linea(v_resultado,'Gastos (+)',2);
              v_gastos:=1;*/
           end if;
           pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
        end if;
        v_linea :=substr(reg.des_transaccion,1,20);
        --v_col_antes := v_ancho - length(v_linea)-30;
        v_linea := rpad(v_linea,20,' ')||lpad(to_char(reg.monto,'999,999,999,999.99'),20,' ');
        pag_imp.pr_imp_linea(v_resultado,v_linea,1);
      end if;
    end loop;
    if v_gastos = 1 then
      pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
    end if;

   --setear para q haga una sóla vez la parte de cargos
    v_una_vez := 'N';
  end if;
  --forma de pago o cobro
  /*for reg in mov loop
    if reg.operacion is not null then
      --forma de pago/cobro
      if v_una_vez ='S' then--para q imprima una sola vez
         if reg.modalidad = 71 then --compra
           pag_imp.pr_imp_linea(v_resultado,'Forma de Pago',2);
         else
           pag_imp.pr_imp_linea(v_resultado,'Forma de Cobro',2);
         end if;
         pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
         v_una_vez :='N';
      end if;

      if reg.operacion = 7 then-- si es cobro de cheque --q no sea cobro cheq //prueba
         v_imp_cheque:='S';
      end if;
      --si es contra cuenta, acortar la descripcion y mostrar el nro. de cuenta
      if reg.operacion = 8 then --cobro debito en cta
        v_linea := 'DEB.CTA '||reg.nro_cuenta;
      elsif reg.operacion =3 then --pago credito en cta
        v_linea := 'CRED.CTA '||reg.nro_cuenta;
      else
       v_linea := substr(reg.des_operacion,1,20);
      end if;
      v_linea := rpad(v_linea,20,' ')||lpad(to_char(reg.monto,'999,999,999,999.99'),20,' ');
      pag_imp.pr_imp_linea(v_resultado,v_linea,1);
    end if;
  end loop;*/
  --detalle de cheque (gcia) pagado si hubiera
  /*for reg1 in cheque loop
     if v_una_vez ='S' then--para q imprima una sola vez
        pag_imp.pr_imp_linea(v_resultado,'Forma de Pago',2);
        pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
        v_una_vez :='N';
     end if;
     v_linea := 'CHEQ.'||reg1.sigla||' '||substr(reg1.nro_documento,1,15);
     v_linea := rpad(v_linea,20,' ')||lpad(to_char(reg1.monto,'999,999,999,999.99'),20,' ');
     pag_imp.pr_imp_linea(v_resultado,v_linea,1);
  end loop;
*/
 /* if v_imp_cheque = 'S' then
     v_una_vez :='S';
     --detalle de cheque cobrado si hubiera NO SE USA,se toma dl mov y no se muestra el nro //prueba
     for reg2 in detalle loop
        if v_una_vez ='S' then--para q imprima una sola vez
           pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),2);
           pag_imp.pr_imp_linea(v_resultado,'Detalle cheques...',2);
           --pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),2);
           v_una_vez :='N';
        end if;
        v_linea := 'CHEQ.'||reg2.sigla||' '||substr(reg2.nro_cheque,1,15);
        v_linea := rpad(v_linea,20,' ')||lpad(to_char(reg2.monto,'999,999,999,999.99'),20,' ');
        pag_imp.pr_imp_linea(v_resultado,v_linea,1);
     end loop;
  end if;*/
  
  end loop;
  
  --comentario x tipo de implementacion
  if fug_obt_tip_implementacion = 3 then
     v_linea:= 'El cumplimiento  de la  obligacion  por';
     pag_imp.PR_IMP_LINEA(v_resultado,v_linea,2);
     v_linea:= 'cada  parte en  esta  transaccion  esta';
     pag_imp.PR_IMP_LINEA(v_resultado,v_linea,1);
     v_linea:= 'sujeta a leyes, regulaciones, decretos,';
     pag_imp.PR_IMP_LINEA(v_resultado,v_linea,1);
     v_linea:= 'y  disposiciones del Gobierno Nacional.';
     pag_imp.PR_IMP_LINEA(v_resultado,v_linea,1);
      --leyenda
      pag_imp.pr_imp_linea(v_resultado, '----------------------------------------', 1, 0);
      pag_imp.pr_imp_linea(v_resultado, 'Este    formato   esta    aprobado   por', 1, 0);
      pag_imp.pr_imp_linea(v_resultado, 'Constancia de Comunicacion N.05484/05F, ', 1, 0);
      pag_imp.pr_imp_linea(v_resultado, 'de la Subsecretaria de Estado de Tribu- ', 1, 0);
      pag_imp.pr_imp_linea(v_resultado, 'tacion de fecha 29/12/2005              ', 1, 0);
      pag_imp.pr_imp_linea(v_resultado, '*Original: Adquirente', 2, 0);
      pag_imp.pr_imp_linea(v_resultado, '                  *Copia1: Contribuyente', 1, 0);
      pag_imp.pr_imp_linea(v_resultado, '                   *Copia2: Arch.Tribut.', 1, 0);
  end if;

  -- imprimo el pie
  pag_imp.pr_imp_pie(v_resultado, 2);   -- linea antes

  v_linea := null;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 10, 0);

  return(v_resultado);

end FUJ_IMP_COMPROBANTE_243;
/

