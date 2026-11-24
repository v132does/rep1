create or replace function it.FUJ_IMP_COMPROBANTE_PR
  (p_cod_oficina IN NUMBER, 
   p_nro_operacion in number,
   p_nro_cuenta  IN VARCHAR,
   p_nro_cuota   IN NUMBER,
   p_fecha       IN DATE,
   p_hora        IN VARCHAR2) 
 return varchar2 is
  v_ancho     number(3) := 45; -- ancho del reporte
  v_resultado varchar2(4000) := null;
  v_linea     varchar2(200);
  v_cod_persona varchar2(15);
  v_nom_completo varchar2(200);
  v_nro_documento varchar2(20);
  v_fec_vencimiento date;
  v_mto_cuota number(18,2);
  v_int_moratorio number(18,2);
  v_int_punitorio number(18,2);
  v_impuesto number(18,2); 
  v_cargo number(18,2);
  v_iva number(18,2);
  v_total number(18,2);    
begin
  -- seteo la oficina
  pag_imp.pr_set_oficina(p_cod_oficina); 
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
/*  -- imprimo la cabecera
  pag_imp.pr_imp_cab_centrada(v_resultado,  -- texto
                           '*** PAGO DE PRESTAMOS ***',  -- titulo
                           'RECIBO DE DINERO: '||to_char(p_nro_operacion), -- sub titulo
                           1, -- lineas antes
                           1); -- lineas despues*/

  -- imprimo la fecha y hora
  v_linea := 'Fecha: '||to_char(p_fecha,'dd/mm/yy')||'  '||p_hora;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 0, /*lin.antes*/ 0, /*col.antes*/ 'S' /* centrado */);    
                       
  -- leo los datos del pago de prestamos
  begin
     select c.cod_persona , c.nom_completo, c.nro_documento,
            a.fec_vencimiento, 
            nvl(a.mto_capital,0)+ nvl(a.mto_interes,0) +
            nvl(a.mto_int_documentado,0) cuota,
            nvl(a.mto_int_moratorio,0) + nvl(a.mto_int_mor_interes,0) +
            nvl(a.mto_int_mor_adelantado,0) int_moratorio,
            nvl(a.mto_int_punitorio,0) int_punitorio,
            nvl(a.mto_impuesto,0) impuesto,
            nvl(a.mto_cargo,0),
            nvl(a.mto_cargo_iva,0) iva
       into v_cod_persona, v_nom_completo, v_nro_documento,
            v_fec_vencimiento, v_mto_cuota,
            v_int_moratorio, v_int_punitorio,
            v_impuesto, v_cargo, v_iva     
      from ba_personas c, ge_cta_clientes b, pr_cobros a
      where a.nro_cuenta = b.nro_cuenta
        and b.relacion = 'P' -- cliente principal
        and c.cod_persona = b.cod_persona
        and a.nro_cuenta = p_nro_cuenta
        and a.nro_cuota = p_nro_cuota
        and a.fecha = p_fecha
        and a.hora = p_hora;
  exception
     when others then
         raise_application_error(-20000,'Error al leer datos del pago '||sqlerrm);
  end; 
  -- total cobrado
  v_total := v_mto_cuota +
             v_int_moratorio +
             v_int_punitorio +
             v_impuesto +
             v_cargo +
             v_iva ;
  -- datos del cliente y el prestamo
  pag_imp.pr_imp_linea(v_resultado, 'Doc.: '||v_nro_documento, 2, 0);    
  pag_imp.pr_imp_linea(v_resultado, 'Sr/a: '||v_nom_completo, 1, 0);    
  pag_imp.pr_imp_linea(v_resultado, 'Prestamo: '||p_nro_cuenta||'   '||'Cuota: '||to_char(p_nro_cuota), 1, 0);    
  pag_imp.pr_imp_linea(v_resultado, 'Recibimos  el  Pago  en  concepto de su', 2, 0,'S');    
  pag_imp.pr_imp_linea(v_resultado, 'Prestamo arriba indicado, segun detalle', 1, 0,'S');    
  -- detalle de los cobros          
  pag_imp.pr_imp_linea(v_resultado, 'Fecha de Vencimiento: '||to_char(v_fec_vencimiento,'dd/mm/yy'), 2, 0);    
  pag_imp.pr_imp_linea(v_resultado, 'Monto de la Cuota   : '||to_char(v_mto_cuota,'999,999,999,999,999.99'), 1, 0);    
  pag_imp.pr_imp_linea(v_resultado, 'Interes Moratorio   : '||to_char(v_int_moratorio,'999,999,999,999,999.99'), 1, 0);    
  pag_imp.pr_imp_linea(v_resultado, 'Interes Punitorio   : '||to_char(v_int_punitorio,'999,999,999,999,999.99'), 1, 0);    
  pag_imp.pr_imp_linea(v_resultado, 'Imp.Ley s/Act.y Doc.: '||to_char(v_impuesto,'999,999,999,999,999.99'), 1, 0);    
  pag_imp.pr_imp_linea(v_resultado, 'Gastos de Cobranza  : '||to_char(v_cargo,'999,999,999,999,999.99'), 1, 0);    
  pag_imp.pr_imp_linea(v_resultado, 'I.V.A. s/ Gastos    : '||to_char(v_iva,'999,999,999,999,999.99'), 1, 0);    
  -- total               
  pag_imp.pr_imp_linea(v_resultado, 'TOTAL PAGADO        : '||to_char(v_total,'999,999,999,999,999.99'), 2, 0);    
  
  -- imprimo el pie   
  pag_imp.pr_imp_pie(v_resultado, 2);   -- linea antes                   
                            
  return(v_resultado);
end FUJ_IMP_COMPROBANTE_PR;
/

