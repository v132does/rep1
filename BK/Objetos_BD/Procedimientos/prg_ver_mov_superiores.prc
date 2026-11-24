CREATE OR REPLACE PROCEDURE IT.PRG_VER_MOV_SUPERIORES
 (P_COD_PERSONA IN VARCHAR2,
  P_COD_MODULO  IN VARCHAR2,
  P_COD_MODALIDAD IN VARCHAR,
  P_NOMBRE IN VARCHAR2,
  P_NRO_DOCUMENTO IN VARCHAR2  ,
  P_TIP_PERSONA IN VARCHAR2  ,
  P_NACIONALIDAD IN VARCHAR2 ,
  P_DIRECCION IN VARCHAR2  ,
  P_CIUDAD IN VARCHAR2,
  P_FECHA IN DATE,
  P_NRO_CUENTA IN VARCHAR2,
  P_RESULTADO OUT VARCHAR2
 )

 IS
   v_mto_sup              gv_movimientos.MONTO%type := fug_obt_pardinamico('OPE_SUP_MON_FUERTE');
   v_tot_ope              number;
   v_ancho               number(3):= 40; -- ancho del reporte
   v_resultado          varchar2(4000) := null;
   v_linea              varchar2(200);
   v_monto             varchar2(50);
   v_nombre             varchar2(110) := P_NOMBRE;
   v_nom_empresa          varchar2(110);
   v_cuenta             varchar2(15) := P_NRO_CUENTA;
   v_cod_moneda         varchar2(3);
   v_nom_oficina          varchar2(35);
   v_documento            varchar2(20) :=  P_NRO_DOCUMENTO;
   v_ruc                varchar2(20);
   v_tip_persona          varchar2(1) :=   P_TIP_PERSONA;
   v_nacionalidad          varchar2(40) :=  P_NACIONALIDAD;
   v_direccion             varchar2(100) := P_DIRECCION;
   v_dir_empresa          varchar2(100);
   v_fecha              varchar2(60) := TO_CHAR(P_FECHA,'dd/mm/yyyy');
   v_cod_modulo         varchar2(3) :=  P_COD_MODULO;
   v_cod_modalidad       varchar2(3) :=  P_COD_MODALIDAD;
   v_ciudad             varchar2(35) := P_CIUDAD;
   v_transaccion          varchar2(40);

   cursor mov_cambios is
       select pal_cam.fu_obt_ofi_cambio(gv_movimientos.cod_ofi_origen) ofi_cambio,
              fue_obt_des_oficina(pal_cam.fu_obt_ofi_cambio(gv_movimientos.cod_ofi_origen)) des_ofi_cambio,
              gv_movimientos.cod_moneda,
              gv_movimientos.cod_tra_padre,
              gv_movimientos.cod_mad_padre,
              gv_movimientos.cod_usuario,
              gv_movimientos.nro_secuencia,
              gv_movimientos.nro_cuenta cta,
              m.descripcion moneda,
              Initcap(mo.descripcion)||' de Divisas' modalidad,
              gv_movimientos.nro_documento,
              Initcap(lc.descripcion) tip_operacion,
              gv_movimientos.fecha fec_mov,
              gv_movimientos.hora hora_mov,
              gv_movimientos.cod_usuario usu_mov,
              gv_movimientos.monto cantidad,
              '***'||trim(to_char(gv_movimientos.monto,'999,999,999,999,999.99')) mto_formateado,
              gv_movimientos.cotizacion,
              gv_movimientos.monto * gv_movimientos.cotizacion monto,
              gv_movimientos.cod_oficina,
              fue_obt_des_oficina(gv_movimientos.cod_oficina) oficina,
              gv_movimientos.cod_ofi_origen,
              gv_movimientos.nro_cuenta,
              decode(gv_movimientos.cod_mad_padre,71,monto) ingreso,
              decode(gv_movimientos.cod_mad_padre,72,monto) egreso,
              fug_des_fecha(gv_movimientos.fecha) des_fecha
      from   ba_monedas m,
             ge_modalidades mo,
             lc_tip_operaciones lc,
             (select to_char(nro_documento2) nro_doc, fecha fecha_cli, hora hora_cli, cod_usuario cod_usuario_cli,
                     b.nom_completo nombre,
                     b.nro_documento,
                     bf.cod_pai_nacionalidad,
                     d.cod_direccion,
                     d.direccion,
                     d.cod_pais,
                     d.cod_ciudad,
                     b.tipo,
                     bj.nom_comercial,
                     bj.raz_social,
                     ge_actividades.descripcion actividad
              from ge_actividades,
                   ba_per_fisicas bf,
                   ba_per_juridicas bj,
                   ba_direcciones d,
                   ba_personas b,
                   ge_movimientos gv_movimientos
             where  b.cod_actividad = ge_actividades.cod_actividad(+)
               and b.cod_persona = bf.cod_persona(+)
               and b.cod_persona = bj.cod_persona(+)
               and d.principal(+) = 'S'
               and b.cod_persona = d.cod_persona(+)
               and b.cod_persona = to_char(gv_movimientos.nro_documento2)
               and gv_movimientos.cod_transaccion = 760
               and nvl(gv_movimientos.protegido,'N') = 'N'
               and gv_movimientos.COD_MOD_PADRE = 7) cliente,
               ge_movimientos gv_movimientos
     where m.cod_moneda = gv_movimientos.cod_moneda
           and mo.cod_modulo = gv_movimientos.COD_MOD_PADRE
           and mo.cod_modalidad = gv_movimientos.COD_MAD_PADRE
           and cliente.fecha_cli = gv_movimientos.fecha
           and cliente.hora_cli  = gv_movimientos.hora
           and cliente.cod_usuario_cli = gv_movimientos.COD_USUARIO
           and gv_movimientos.cod_tip_ope_cambio = lc.cod_tip_operacion
           and gv_movimientos.COD_MOD_PADRE = 7
           and nvl(gv_movimientos.protegido,'N') = 'N'
           and gv_movimientos.nro_secuencia = 1
           and gv_movimientos.cod_mad_padre in (71,72)
           and cliente.nro_doc = p_cod_persona
           and gv_movimientos.fecha = p_fecha
           and pag_gen.fu_con_mon_a_moneda(gv_movimientos.cod_moneda,'USD', gv_movimientos.monto, gv_movimientos.cotizacion) <= fug_obt_pardinamico('OPE_SUP_MON_FUERTE')
           and gv_movimientos.estado <> 'J';--JCLG

   cursor mov_cuentas is
    select  (decode(m.cod_moneda,'USD',m.monto,
                                          pag_gen.FU_CON_MON_A_MONEDA(m.cod_moneda,
                                          'USD',
                                          m.monto,
                                          m.cotizacion))) monto,
             c.cod_persona,
             m.nro_secuencia,
             m.hora,
             m.fecha,
             m.cod_usuario,
             m.cod_moneda,
             t.abreviatura tip_operacion,
             '***'||trim(to_char(m.monto,'999,999,999,999,999.99')) mto_formateado,
             m.nro_documento
    from ge_movimientos m ,
         ge_cta_clientes c,
         ge_transacciones t
   where c.relacion = 'P'
     and m.nro_cuenta = c.nro_cuenta
     and m.cod_transaccion = t.cod_transaccion
     and m.cod_modalidad = t.cod_modalidad
     and m.cod_modulo = t.cod_modulo
     and m.nro_caja is not null
     and m.reversado = 'N'
     and m.cod_mod_padre <> 7
     and c.cod_persona = p_cod_persona
     and m.fecha = p_fecha
     and nvl(m.protegido,'N') = 'N'
     and not exists (select 1 from ah_cta_certificados where nro_cuenta = m.nro_cuenta
                                                       and nro_cta_renovada is not null)
     -- No incluir CDA renovados
     and m.monto > 0
     and m.cod_modulo in (3,4)
     and m.cod_tra_padre in (136,351,352)
     and pag_gen.fu_con_mon_a_moneda(m.cod_moneda,'USD', m.monto, m.cotizacion) <= fug_obt_pardinamico('OPE_SUP_MON_FUERTE')
     and m.estado <> 'J';
begin
   -- seteo el ancho del reporte
   pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
   ----- Imprimir declaración de movimientos
   pag_imp.PR_CONDENSADO(v_resultado,'S'); -- activa impresion condensada
   pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita
   --pag_imp.pr_imp_linea(v_resultado, '      ANEXO RESOLUCION No. 245/97', 1, 1);
   --pag_imp.pr_imp_linea(v_resultado, '      INFORME SOBRE TRANSACCIONES', 1, 1);
  pag_imp.pr_imp_linea(v_resultado, '      ANEXO RESOLUCION Nro.  60/10', 1, 1);
  pag_imp.pr_imp_linea(v_resultado, '      REGISTRO SOBRE TRANSACCIONES', 1, 1);
   pag_imp.pr_imp_linea(v_resultado, '1-) IDENTIDAD DEL INDIVIDUO QUE SE PRE', 2, 0);
   pag_imp.pr_imp_linea(v_resultado, 'SENTA A REALIZAR LA OPERACION', 1, 0);
   pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita
   pag_imp.pr_imp_linea(v_resultado, rpad('Nombres y Apellidos: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Dto.Ident. Presentado Nro: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('R.U.C. Nro: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Nacionalidad: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Direccion: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Ocupacion o Ramo del Negocio: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('.',40,'.'), 1, 0);
   pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita
   pag_imp.pr_imp_linea(v_resultado, '2-) PERSONA POR CUYA ORDEN SE REALIZA LA', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'TRANSACCION', 1, 0);
   pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita

   if v_tip_persona = 'J' then
      v_nom_empresa := v_nombre;
      v_nombre := '.';
      v_ruc := v_documento;
      v_documento := '.';
      v_dir_empresa := v_direccion;
      v_direccion := '.';
      v_nacionalidad := '.';
      pag_imp.pr_imp_linea(v_resultado, 'Nombre de la Empresa: '||v_nom_empresa, 1, 0);
      pag_imp.pr_imp_linea(v_resultado, 'R.U.C. Nro: '||v_ruc, 1, 0);
      pag_imp.pr_imp_linea(v_resultado, rpad('Direccion: '||v_dir_empresa,40,'.'), 1, 0);
      pag_imp.pr_imp_linea(v_resultado, rpad('Actividad: ',40,'.'), 1, 0);
   else
      pag_imp.pr_imp_linea(v_resultado, 'Nombres y Apellidos: '||v_nombre, 1, 0);
      pag_imp.pr_imp_linea(v_resultado, rpad('Dto.Ident. Presentado Nro: '||v_documento,40,'.'), 1, 0);
      pag_imp.pr_imp_linea(v_resultado, 'Nacionalidad: '||v_nacionalidad, 1, 0);
      pag_imp.pr_imp_linea(v_resultado, rpad('Direccion: '||v_direccion,40,'.'), 1, 0);
      pag_imp.pr_imp_linea(v_resultado, rpad('Ciudad: '||v_ciudad,40,'.'), 1, 0);
   end if;
   pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita

   pag_imp.pr_imp_linea(v_resultado, '3-) MOVIMIENTOS EN CUENTA(S)', 2, 0);
   pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita

   pag_imp.pr_imp_linea(v_resultado, rpad('Ingresos: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Egresos: ',40,'.'), 1, 0);

   if v_cod_modulo = 3 then
      if v_cod_modalidad = 31 then--Ahorro Vista
         pag_imp.pr_imp_linea(v_resultado, rpad('Dep. de Ahorro Nro: '||v_cuenta,40,'.'), 1, 0);
      elsif v_cod_modalidad = 33 then--Certificados
         pag_imp.pr_imp_linea(v_resultado, rpad('Dep. a Plazo Fijo Nro: '||v_cuenta,40,'.'), 1, 0);
      end if;
   elsif v_cod_modulo = 4 then
      if v_cod_modalidad = 41 then--Cuentas Corrientes
         pag_imp.pr_imp_linea(v_resultado, rpad('Cta.Cte.Nros: '||v_cuenta,40,'.'), 1, 0);
      end if;
   elsif v_cod_modulo = 6 then--Prestamos
      pag_imp.pr_imp_linea(v_resultado, rpad('Prestamos: '||v_cuenta,40,'.'), 1, 0);
   end if;

   pag_imp.pr_imp_linea(v_resultado, rpad('Otros: ',40,'.'), 1, 0);
   pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita

   pag_imp.pr_imp_linea(v_resultado, '4-) TIPOS DE TRANSACCIONES Y MONTOS', 2, 0);

   pag_imp.pr_imp_linea(v_resultado, 'TIPO   Mon.Comprob. Monto', 2, 0);
   pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita

   begin
      for reg in mov_cambios loop
         v_transaccion := rpad(reg.tip_operacion,7,' ')||rpad(reg.cod_moneda,4,' ')||
         rpad(reg.nro_documento,7,' ')||rpad(reg.mto_formateado,22,' ');
         pag_imp.pr_imp_linea(v_resultado,v_transaccion, 1, 0);
      end loop;
   end;

   begin
      for reg in mov_cuentas loop
         v_transaccion := rpad(reg.tip_operacion,7,' ')||rpad(reg.cod_moneda,4,' ')||
         rpad(reg.nro_documento,7,' ')||rpad(reg.mto_formateado,22,' ');
         pag_imp.pr_imp_linea(v_resultado,v_transaccion, 1, 0);
      end loop;
   end;

   pag_imp.pr_imp_linea(v_resultado, rpad(v_cod_moneda||': '||v_monto,40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'Fecha de Transaccion: ', 1,0);
   pag_imp.pr_imp_linea(v_resultado, v_fecha, 1,0);
   --pag_imp.pr_imp_linea(v_resultado, 'ESTE FORMULARIO TIENE CARACTER DE DECLA', 2, 0);
   --pag_imp.pr_imp_linea(v_resultado, 'RACION JURADA Y SEGUN RESOLUCION No.2,', 1, 0);
   --pag_imp.pr_imp_linea(v_resultado, 'ACTA No.84  DE FECHA 02 DE MAYO DE 1997', 1, 0);
   --pag_imp.pr_imp_linea(v_resultado, 'DEL DIRECTORIO DEL BANCO CENTRAL DEL PA', 1, 0);
   --pag_imp.pr_imp_linea(v_resultado, 'RAGUAY DEBE SER LLENADO POR CADA OPERA', 1, 0);
   --pag_imp.pr_imp_linea(v_resultado, 'CION EN DOLARES O EQUIVALENTE EN OTRAS', 1, 0);
   --pag_imp.pr_imp_linea(v_resultado, 'MONEDAS CUYO MONTO SERA SUPERIOR A USD', 1, 0);
   --pag_imp.pr_imp_linea(v_resultado, '10,000.00-(DIEZ MIL)', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'ESTE FORMULARIO TIENE CARACTER DE DECLA', 2, 0);
   pag_imp.pr_imp_linea(v_resultado, 'RACION  JURADA Y SEGUN RESOLUCION  Nro.', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, '349/2013 DE LA SECRETARIA DE PREVENCION', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'DE LAVADO DE DINERO O  BIENES (SEPRELAD)', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'DEBE  SER LLENADO  POR  CADA  OPERACION,', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'CUYO IMPORTE EN FORMA UNICA, FRACCIONADA' , 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'O MULTIPLE, SEA SUPERIOR A USD', 1, 0);
   pag_imp.pr_imp_linea(v_resultado,
          to_char(fug_obt_pardinamico('OPE_SUP_MON_FUERTE'),'999g999g999d00')||'-('||
          upper(fue_obt_denominacion(fug_obt_pardinamico('OPE_SUP_MON_FUERTE')))||') ', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'O SU EQUIVALENTE EN OTRAS MONEDAS', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'Se deja constancia que la informacion', 2, 0);
   pag_imp.pr_imp_linea(v_resultado, 'proveida en este formulario ha sido obte', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'nida de documentos exhibidos y datos pro', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'veidos por los declarantes de la presen', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'te transaccion sin que la ENTIDAD OPERAN', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'TE, por tanto, asuma responsabilidad al', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'guna acerca de la autenticidad de los', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'mismos', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Firma del Declarante(s) ',40,'.'), 2, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Aclaracion de Firma(s)',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('.',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'Lugar y Fecha: ', 2, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad(v_nom_oficina||', '||v_fecha||' ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Sello y Firma de la Entidad',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, ' ', 18, 0);

   begin
      for reg in mov_cambios loop
         update ge_movimientos
         set protegido = 'S'
         where fecha = reg.fec_mov
         and hora = reg.hora_mov
         and nro_secuencia = reg.nro_secuencia
         and cod_usuario = reg.cod_usuario
         and pag_gen.fu_con_mon_a_moneda(cod_moneda,'USD', monto,cotizacion) <= fug_obt_pardinamico('OPE_SUP_MON_FUERTE');
      end loop;
   end;

   begin
      for reg in mov_cuentas loop
         update ge_movimientos
         set protegido = 'S'
         where fecha = reg.fecha
         and hora = reg.hora
         and nro_secuencia = reg.nro_secuencia
         and cod_usuario = reg.cod_usuario
         and pag_gen.fu_con_mon_a_moneda(cod_moneda,'USD', monto,cotizacion) <= fug_obt_pardinamico('OPE_SUP_MON_FUERTE');
      end loop;
   end;
   p_resultado := v_resultado;
end;
/

