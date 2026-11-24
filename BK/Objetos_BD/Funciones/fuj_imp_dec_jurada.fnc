CREATE OR REPLACE FUNCTION IT.FUJ_IMP_DEC_JURADA
  (p_fecha                  in date,
   p_hora                    in varchar2,
   p_cod_usuario            in varchar2,
   p_secuencia              in number default null)
 return varchar2 is
  v_ancho           number(3):= 132; -- ancho del reporte
  v_resultado      varchar2(4000) := null;
  v_linea          varchar2(200);
  v_monto           varchar2(22);
  v_nombre         varchar2(110);
  v_nom_empresa     varchar2(110);
  v_cuenta         varchar2(15);
  v_cod_moneda     varchar2(3);
  v_nom_oficina     varchar2(35);
  v_documento       varchar2(20);
  v_ruc              varchar2(20);
  v_tip_persona     varchar2(1);
  v_nacionalidad   varchar2(40);
  v_direccion        varchar2(90);
  v_dir_empresa     varchar2(90);
  v_transaccion     varchar2(60);
  v_cod_tra_padre  number(4);
  v_fecha          varchar2(60);
  v_cod_modulo     varchar2(3);
  v_cod_modalidad   varchar2(3);
  v_ciudad         varchar2(35);
  v_cod_persona     varchar2(10);
  v_cod_mad_padre  number(5);

begin
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante

  -- leo los datos del movimiento
  begin
      select '***'||trim(to_char(a.monto,'999,999,999,999,999.99')), a.nro_cuenta, a.cod_moneda,
      b.descripcion, substr(d.nom_completo,1,110), d.nro_documento, d.tipo, e.nacionalidad,
      nvl(f.direccion||decode(numero,null,'',' '||numero),' '), a.cod_tra_padre, fug_des_fecha(p_fecha), a.cod_modulo,
      a.cod_modalidad, d.cod_persona, a.cod_mad_padre
      into v_monto, v_cuenta, v_cod_moneda, v_nom_oficina, v_nombre, v_documento,
      v_tip_persona, v_nacionalidad, v_direccion, v_cod_tra_padre, v_fecha, v_cod_modulo,
      v_cod_modalidad, v_cod_persona, v_cod_mad_padre
      from ba_oficinas b, ge_cta_clientes c,
           ba_personas d, ba_paises e, ba_direcciones f,
           (select cod_modulo, cod_modalidad, nro_cuenta,
                   cod_mad_padre, cod_tra_padre, cod_ofi_origen,
                   cod_moneda, sum(monto) monto
              from ge_movimientos
             where fecha = p_fecha
               and hora = p_hora
               and cod_usuario = p_cod_usuario
               and cod_tra_padre not in (517,598)
               and (nro_secuencia = p_secuencia or p_secuencia is null)
             group by cod_modulo, cod_modalidad, nro_cuenta, cod_moneda,
                   cod_mad_padre, cod_tra_padre, cod_ofi_origen
           ) a
      where a.cod_ofi_origen = b.cod_oficina
      and a.nro_cuenta = c.nro_cuenta
      and c.relacion = 'P'
      and c.cod_persona = d.cod_persona
      and d.cod_pais = e.cod_pais
      and d.cod_persona = f.cod_persona(+)
      and 'S' = f.principal(+);

  exception
     when no_data_found then
           select '***'||trim(to_char(g.monto,'999,999,999,999,999.99')), a.nro_cuenta, g.cod_moneda,
                b.descripcion, substr(d.nom_completo,1,110), d.nro_documento, d.tipo, e.nacionalidad,
                nvl(f.direccion||decode(numero,null,'',' '||numero),' '), g.cod_tra_padre, fug_des_fecha(p_fecha), g.cod_modulo,
                g.cod_modalidad, d.cod_persona, g.cod_mad_padre
                into v_monto, v_cuenta, v_cod_moneda, v_nom_oficina, v_nombre, v_documento,
                v_tip_persona, v_nacionalidad, v_direccion, v_cod_tra_padre, v_fecha, v_cod_modulo,
                v_cod_modalidad, v_cod_persona, v_cod_mad_padre
                from ba_oficinas b, ba_personas d, ba_paises e, ba_direcciones f,
                     ge_movimientos g,
                     (select cod_modulo, cod_modalidad, nro_cuenta,
                             cod_mad_padre, cod_tra_padre, cod_ofi_origen,
                             cod_moneda, sum(monto) monto, to_char(nro_documento2) cod_persona
                        from ge_movimientos
                       where fecha = p_fecha
                         and hora = p_hora
                         and cod_usuario = p_cod_usuario
                         and cod_transaccion = 760
                       group by cod_modulo, cod_modalidad, nro_cuenta, cod_moneda,
                             cod_mad_padre, cod_tra_padre, cod_ofi_origen, to_char(nro_documento2)
                     ) a
                where g.cod_ofi_origen = b.cod_oficina
                and a.cod_persona = d.cod_persona
                and d.cod_pais = e.cod_pais
                and g.fecha = p_fecha
                and g.hora = p_hora
                and g.cod_usuario = p_cod_usuario
                and g.nro_secuencia = 1
                and d.cod_persona = f.cod_persona(+)
                and 'S' = f.principal(+);
     when others then
           raise_application_error(-20000,'Error al leer el movimiento'||sqlerrm);
  end;

  -- recupero la descripcion cod_tra_padre
  begin
      select descripcion
      into v_transaccion
      from ge_transacciones
      where cod_transaccion = v_cod_tra_padre
        and cod_modalidad = v_cod_mad_padre;
  exception
     when others then
           raise_application_error(-20000,'Error al recuperar descripcion transaccion'||sqlerrm);
  end;

  -- recupero la ciudad de la dirección
  begin
      select a.descripcion
      into v_ciudad
      from ba_ciudades a, ba_direcciones b
      where a.cod_ciudad = b.cod_ciudad
      and b.cod_persona = v_cod_persona
      and b.principal = 'S'
      and b.cod_pais = a.cod_pais;
  exception
     when no_data_found then
           v_ciudad:='.';
     when others then
           raise_application_error(-20000,'Error al recuperar nombre de ciudad'||sqlerrm);
  end;


  --Detalle de Impresión
  pag_imp.PR_CONDENSADO(v_resultado,'S'); -- activa impresion condensada
  pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita
  --pag_imp.pr_imp_linea(v_resultado, 'ANEXO RESOLUCION No. 245/97', 1, 27);
  --pag_imp.pr_imp_linea(v_resultado, 'INFORME SOBRE TRANSACCIONES', 1, 27);
  pag_imp.pr_imp_linea(v_resultado, 'ANEXO RESOLUCION Nro.  60/10', 1, 27);
  pag_imp.pr_imp_linea(v_resultado, 'REGISTRO SOBRE TRANSACCIONES', 1, 27);
  pag_imp.pr_imp_linea(v_resultado, '1-) IDENTIDAD DEL INDIVIDUO QUE SE PRESENTA A REALIZAR LA OPERACION.', 2, 0);
  pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita
  pag_imp.pr_imp_linea(v_resultado, rpad('Nombres y Apellidos: ',132,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad('Dto.Ident. Presentado Nro: ',80,'.')||rpad('R.U.C. Nro: ',52,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad('Nacionalidad: ',132,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad('Direccion: ',132,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad('Ocupacion o Ramo del Negocio: ',132,'.'), 1, 0);

  pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita
  pag_imp.pr_imp_linea(v_resultado, '2-) PERSONA POR CUYA ORDEN SE REALIZA LA TRANSACCION', 2, 0);
  pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita
  if v_tip_persona = 'J' then
    v_nom_empresa := v_nombre;
    v_nombre := '.';
    v_ruc := v_documento;
    v_documento := '.';
    v_dir_empresa := v_direccion;
    v_direccion := '.';
    v_nacionalidad := '.';

    pag_imp.pr_imp_linea(v_resultado, 'Si el ORDENANTE fuese una EMPRESA:', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Nombre de la Empresa: '||v_nom_empresa, 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'R.U.C. Nro: '||v_ruc, 1, 0);
    pag_imp.pr_imp_linea(v_resultado, rpad('Dirección: '||v_dir_empresa,80,' ')||'Actividad: ', 1, 0);
  else
    pag_imp.pr_imp_linea(v_resultado, 'Si el ORDENANTE fuese mas de una persona, indicar el principal', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Nombres y Apellidos: '||v_nombre, 1, 0);
    pag_imp.pr_imp_linea(v_resultado, rpad('Dto.Ident. Presentado Nro: '||v_documento,80,' ')||'R.U.C. Nro: ', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Nacionalidad: '||v_nacionalidad, 1, 0);
    pag_imp.pr_imp_linea(v_resultado, rpad('Dirección: '||v_direccion,80,'.')||rpad('Ciudad: '||v_ciudad,52,'.'), 1, 0);
  end if;
  pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita
  pag_imp.pr_imp_linea(v_resultado, '3-) MOVIMIENTOS EN CUENTA(S)', 2, 0);
  pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita
  pag_imp.pr_imp_linea(v_resultado, rpad('Ingresos: ',80,'.')||rpad('Egresos: ',52,'.'), 1, 0);
  if v_cod_modulo = 3 then
     if v_cod_modalidad = 31 then--Ahorro Vista
        pag_imp.pr_imp_linea(v_resultado, rpad('Dep. de Ahorro Nro: '||v_cuenta,132,'.'), 1, 0);
     elsif v_cod_modalidad in (33,35) then--Certificados
        pag_imp.pr_imp_linea(v_resultado, rpad('Dep. a Plazo Fijo Nro: '||v_cuenta,132,'.'), 1, 0);
     end if;
  elsif v_cod_modulo = 4 then
     if v_cod_modalidad = 41 then--Cuentas Corrientes
        pag_imp.pr_imp_linea(v_resultado, rpad('Cta.Cte.Nros: '||v_cuenta,132,'.'), 1, 0);
     end if;
  elsif v_cod_modulo = 6 then--Prestamos
      pag_imp.pr_imp_linea(v_resultado, rpad('Prestamos: '||v_cuenta,132,'.'), 1, 0);
  end if;
  pag_imp.pr_imp_linea(v_resultado, rpad('Otros: ',132,'.'), 1, 0);
  pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita
  pag_imp.pr_imp_linea(v_resultado, '4-) TIPOS DE TRANSACCIONES Y MONTOS', 2, 0);
  pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita
  pag_imp.pr_imp_linea(v_resultado, rpad('Monto de la Transaccion '||v_cod_moneda||': '||v_monto,132,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad(v_transaccion,132,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'Fecha de Transacción: '||v_fecha, 1,0);
  --pag_imp.pr_imp_linea(v_resultado, 'ESTE FORMULARIO TIENE CARACTER DE DECLARACION JURADA Y SEGUN RESOLUCION No.2, ACTA No.84  DE FECHA 02 DE MAYO DE 1997 DEL DIRECTORIO', 2, 0);
  --pag_imp.pr_imp_linea(v_resultado, 'DEL  BANCO  CENTRAL  DEL  PARAGUAY  DEBE  SER  LLENADO  POR  CADA  OPERACION  EN  DOLARES O EQUIVALENTE EN OTRAS MONEDAS CUYO  MONTO', 1, 0);
  --pag_imp.pr_imp_linea(v_resultado, 'SERA SUPERIOR A USD 10,000.00----(DIEZ MIL)', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'ESTE FORMULARIO TIENE CARACTER DE DECLARACION JURADA Y SEGUN RESOLUCION Nro. 349/2013 DE LA ', 2, 0);
  pag_imp.pr_imp_linea(v_resultado, 'SECRETARIA DE PREVENCION DE LAVADO DE DINERO O BIENES (SEPRELAD) DEBE SER LLENADO  POR  CADA OPERACION CUYO IMPORTE, EN FORMA UNICA,', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, ' FRACCIONADA O MULTIPLE, SEA SUPERIOR A USD '|| to_char(fug_obt_pardinamico('OPE_SUP_MON_FUERTE'),'999g999g999d00')||'-('|| upper(fue_obt_denominacion(fug_obt_pardinamico('OPE_SUP_MON_FUERTE')))||')'||' O SU EQUIVALENTE EN OTRAS MONEDAS', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'Se deja  constancia  que  la  información proveída en este formulario ha sido obtenida de documentos exhibidos y datos proveidos por ', 2, 0);
  pag_imp.pr_imp_linea(v_resultado, 'los declarantes de  la presente transacción sin que la ENTIDAD OPERANTE,  por tanto,  asuma  responsabilidad  alguna  acerca  de  la ', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'autenticidad de los mismos', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad('Firma del Declarante(s) ',132,'.'), 2, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad('.',132,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'Aclaracion de Firma(s)', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad('Lugar y Fecha '||v_nom_oficina||', '||v_fecha||' ',100,'.')||'Sello y Firma de la Entidad', 2, 0);
  --v_resultado:=LENGTH(v_resultado);
  return(v_resultado);
exception
when others  then
   return null;
end FUJ_IMP_DEC_JURADA;
/

