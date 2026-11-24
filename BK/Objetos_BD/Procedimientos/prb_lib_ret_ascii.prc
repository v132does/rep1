CREATE OR REPLACE PROCEDURE IT.prb_lib_ret_ascii IS
  /* Procediemto: Genera archivos a partir de la tabla de retenciones */
  /* IT --> 26/ene/2010 */
  v_directorio VARCHAR2(30);
  v_archivo       UTL_FILE.FILE_TYPE;
  con NUMBER :=0;
  v_cant_reg number :=0;
  v_cant_arc number :=0;
  v_periodo_fiscal_ini ge_calendarios.fec_actual%type;
  v_periodo_fiscal_fin ge_calendarios.fec_actual%type;
  v_fec_arc ge_calendarios.fec_actual%type;

  v_sentencia varchar2(150) := 'TRUNCATE TABLE cb_lib_retencion';
  v_error varchar2(3000);
  v_timbrado  varchar2(20);

-- obtener y generar datos cabecera
PROCEDURE LP_GEN_DAT_CABECERA(p_archivo in UTL_FILE.FILE_TYPE,
                              p_periodo_fiscal_ini in date,
                              p_periodo_fiscal_fin in date,
                              p_can_reg_gen in number);
-- obtener y generar datos para el detalle de factura
PROCEDURE LP_GEN_DAT_DETALLE(p_archivo in UTL_FILE.FILE_TYPE,
                              p_periodo_fiscal_ini in date,
                              p_periodo_fiscal_fin in date,
                              p_can_reg_gen in number);

----------------------------------------------------------------------------
PROCEDURE LP_GEN_DAT_CABECERA(p_archivo in UTL_FILE.FILE_TYPE,
                              p_periodo_fiscal_ini in date,
                              p_periodo_fiscal_fin in date,
                              p_can_reg_gen in number)
IS
   v_registro              VARCHAR2(300);
   v_ruc_entidad           varchar2(15) :=' ';
   v_nom_entidad           varchar2(60);
   v_ruc_representante     varchar2(20);
   v_nom_representante     varchar2(60);
   v_cod_per_representante ba_personas.cod_persona%type;
   v_total                 number(18) :=0;
   v_cont_reg              number :=0;
   cursor acumula_retencion is
     select Decode(t.nom_completo,'','SIN NOMBRE',ltrim(rtrim(t.nom_completo))) nombre,
          t.fec_pago,
          t.nro_factura,
          t.nro_timbrado,
          t.cod_persona,
          t.ruc_retenido,
          t.ruc_proveedor,
          t.nro_com_retencion,
          t.fec_com_retencion,
          t.mto_ret_renta,
          t.mto_ret_iva,
          t.imp_ret_renta,
          t.imp_ret_iva,
          t.mto_exento,
          t.imp_ret_exento
     from cb_lib_retencion t
     where t.fec_com_retencion between p_periodo_fiscal_ini and  p_periodo_fiscal_fin
      and procesado = 'N'
      and rownum <= p_can_reg_gen
     order by fec_pago, nro_factura;

BEGIN
   -- Recupera datos de la Entidad
  select nro_documento, nom_completo
     into v_ruc_entidad, v_nom_entidad
     from ba_personas p, ge_par_generales g
    where g.cod_persona = p.cod_persona;
    -- Datos del representante legal
    v_cod_per_representante := FUG_OBT_PARDINAMICO('BAL_IMP_REP_LEGAL');
    -- debe ir en este orden Apellidos y Nombres del representante legal
    begin
      select p.nom_completo, p.nro_documento
        into v_nom_representante, v_ruc_representante
        from ba_personas p
       where p.cod_persona = v_cod_per_representante;
    exception
       when no_data_found then
          raise_application_error(-20000,'Representante no registrado');
    end;

    for i in acumula_retencion loop
       begin
         v_cont_reg        := v_cont_reg + 1;
         v_total           := v_total + (nvl(i.imp_ret_iva,0) + nvl(i.imp_ret_renta,0));
         -- actualizamos estos registros con un flag en lib ventas para generar los datos de estos mismos en el detalle
         begin
           update cb_lib_retencion
              set procesado = 'X'
            where nro_factura  = i.nro_factura
              and nro_timbrado = i.nro_timbrado
              and fec_com_retencion  = i.fec_com_retencion
              and procesado    = 'N';
          exception
             when others then
                null;
         end;
       end;
    end loop;
    v_registro := '1'||CHR(09)||   -- tipo de registro
                  to_char(p_periodo_fiscal_ini, 'yyyymm')||CHR(09)||-- periodo aaaammm
                  '1'||CHR(09)||  -- tipo de reporte 1= original; 2= Rectificativa
                  '931'||CHR(09)|| -- tipo de informe
                  '231'||CHR(09)|| -- cod. formulario
                  substr(v_ruc_entidad, 1,instr(v_ruc_entidad,'-')-1)||CHR(09)||-- ruc de brios
                  substr(v_ruc_entidad, instr(v_ruc_entidad,'-')+1, length(v_ruc_entidad) - instr(v_ruc_entidad,'-'))||CHR(09)|| -- dv
                  substr(v_nom_entidad,1,80)||CHR(09)|| -- razon social
                  v_ruc_representante||CHR(09)|| -- ruc representante legal
                  fue_obt_ruc_dig_verificador(v_ruc_representante)||CHR(09)|| -- dv rep legal
                  substr(v_nom_representante,1,80)||CHR(09)|| -- nom representante legal
                  v_cont_reg||CHR(09)|| -- cantidad de reg reportados en el detall
                  v_total||CHR(09)||  -- total imp_ret_renta + imp_ret_iva;
                  '2';
  pag_arc.pr_arc_escribir( v_registro, p_archivo );
  con := con + 1;
END;


 -- generamos detalle de las facturas de ventas
PROCEDURE LP_GEN_DAT_DETALLE(p_archivo in UTL_FILE.FILE_TYPE,
                             p_periodo_fiscal_ini in date,
                             p_periodo_fiscal_fin in date,
                             p_can_reg_gen in number)
IS
   v_ruc_entidad           varchar2(15) :=' ';
   v_nom_entidad           varchar2(60);
   v_registro2             varchar2(300);
   fec_factura             date;
   -- cursor para generar detalle
   cursor detalle is
   select Decode(t.nom_completo,'','SIN NOMBRE',ltrim(rtrim(t.nom_completo))) nombre,
          t.fec_pago,
          t.nro_factura,
          t.nro_timbrado,
          t.cod_persona,
          t.ruc_retenido,
          t.ruc_proveedor,
          t.nro_com_retencion,
          t.fec_com_retencion,
          t.mto_ret_renta,
          t.mto_ret_iva,
          t.imp_ret_renta,
          t.imp_ret_iva,
          t.mto_exento,
          t.imp_ret_exento
     from cb_lib_retencion t
    where t.fec_com_retencion between p_periodo_fiscal_ini and  p_periodo_fiscal_fin
      and procesado = 'X' -- este es el estado en el que dejamos los registros a ser procesado en el archivo
      and rownum <= p_can_reg_gen
    order by fec_pago, nro_factura;

BEGIN

  for j in detalle loop
   v_registro2 :=  2||chr(09)|| -- tipo de registro
                   j.ruc_retenido||chr(09)|| -- ruc
                   j.ruc_proveedor||chr(09)|| -- dv
                   j.nombre||chr(09)|| -- Nombre o Razon Social
                   1||chr(09)|| -- tipo de operacion (ver si esta bien)
                   to_char(j.fec_pago,'dd/mm/yyyy')||chr(09)|| -- fecha factura
                   J.Nro_Factura||chr(09)|| -- nro factura
                   j.nro_com_retencion||chr(09)|| -- nro comprobante de retencion
                   to_char(j.fec_com_retencion,'dd/mm/yyyy')||chr(09)|| -- fecha comprobante de retencion
                   lpad(nvl(j.mto_ret_renta,0), 20, '0')||chr(09)|| -- Monto imponible retencion renta
                   j.mto_ret_iva ||chr(09)|| -- Monto Imponible Retencion IVA
                   j.imp_ret_iva ||chr(09)|| -- Importe Retenido IVA
                   lpad(nvl(j.imp_ret_renta,0), 20, '0')||CHR(09)|| -- Importe Retenido Renta
                   j.nro_timbrado||CHR(09)||
                   lpad(nvl(j.mto_exento,0), 20, '0')||CHR(09)||
                   lpad(nvl(j.imp_ret_exento,0), 20, '0');

     pag_arc.pr_arc_escribir(v_registro2, p_archivo);
     con := con + 1;
     -- actualizamos el flag en cb_lib_retencion para que no tome en la otra generacion
     update cb_lib_retencion
        set procesado = 'S'
      where fec_com_retencion  = j.fec_com_retencion
        and nro_factura  = j.nro_factura
        and nro_timbrado = j.nro_timbrado
        and procesado    = 'X';
  end loop;
END;
--------- Proceso Principal --------------
BEGIN
   --v_directorio :='/u02/oradata/it/utl';
   v_directorio :=FUG_OBT_PARDINAMICO('DIR_REP_FTP');--'/oradata/utl';
   -------------------------------------------------------------------------------------------
   /*Primero truncamos la tabla para poder insertar los datos a procesar*/
   -------------------------------------------------------------------------------------------
   sql_util.ejecute_dml(v_sentencia, v_error);
   -- recuperamos el periodo fiscal a partir del calendario
    select g.pri_dia_mes,      g.ult_dia_mes
    into v_periodo_fiscal_ini,v_periodo_fiscal_fin
    from ge_calendarios g
    where g.cod_modulo = 1; -- general
   -- seteo al mes anterior, se procesa por mes cerrado
   v_periodo_fiscal_ini := add_months(v_periodo_fiscal_ini,-1); --OJO le deje del mes
   v_periodo_fiscal_fin := add_months(v_periodo_fiscal_fin,-1); --OJO le deje del mes
   ---
   v_fec_arc := v_periodo_fiscal_fin;

   -- cargamos los datos en la tabla retencion

   insert into cb_lib_retencion(
      nro_factura, nro_timbrado,
      fec_pago,cod_persona,
      nom_completo,ruc_retenido, ruc_proveedor,
      nro_com_retencion, fec_com_retencion,
      mto_ret_renta, mto_ret_iva,
      imp_ret_renta, imp_ret_iva, procesado)
   select a.nro_factura, fub_obt_nro_timbrado('R',fug_obt_ofi_cliente(fue_obt_per_ente(a.cod_proveedor)))/*nvl(prov.timbrado,fug_obt_parentes(a.cod_proveedor,'ULT_NRO_TIMBRADO'))*/, nvl(prov.fecha,a.fec_pago),
      (select cod_persona from ge_entes where cod_ente= a.cod_proveedor and tipo= 'PV'),
      FUE_OBT_NOM_ENTE((select cod_ente from ge_entes where cod_ente= a.cod_proveedor and tipo= 'PV')),
      nvl(substr(prov.ruc, 1, instr(prov.ruc, '-') -1),
          decode(instr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)),'-'),0,--si no tiene ruc como documento
                 fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)), --toma el nro_documento
                 substr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)), 1,
                       instr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)),'-') -1)))  ruc_retenido,
      nvl(substr(prov.ruc, instr(prov.ruc, '-') + 1, length(prov.ruc) - instr(prov.ruc, '-')),
          decode(instr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)),'-'),0,--si no tiene ruc como documento
                 fue_obt_ruc_dig_verificador(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor))), --calcula el dígito verificados
                 substr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)), instr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)), '-') +1,
                        length(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor))) - instr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)), '-')))) ruc_digito,
      /*SUBSTR(LPAD(a.nro_retencion,13,'0'),1,3)||'-'||SUBSTR(LPAD(a.nro_retencion,13,'0'),4,3)
      ||'-'||SUBSTR(LPAD(a.nro_retencion,13,'0'),7,7),*/
      nvl(SUBSTR(LPAD(rv.nro_ret_tesaka,13,'0'),1,3),'999')||'-'||nvl(SUBSTR(LPAD(rv.nro_ret_tesaka,13,'0'),4,3),'999')
      ||'-'||nvl(SUBSTR(LPAD(rv.nro_ret_tesaka,13,'0'),7,7),'9999999'),
       a.fec_pago,
      pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,a.mto_renta,a.cotizacion),
      pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,a.monto_iva,a.cotizacion) monto_iva,
      pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,a.mto_ret_renta,a.cotizacion),
      pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,a.monto_retencion,a.cotizacion) monto_retencion, 'N'
   from ge_ret_proveedores a, pv_compras prov,ge_ret_vir_proveedores rv
   where a.nro_factura = prov.nro_factura (+) --outter join para las retenciones del exterior q se levantan por archivo y no tienen fact. correspondiente
   and a.cod_proveedor = prov.cod_ent_proveedor (+)
   and a.fec_pago  between v_periodo_fiscal_ini and  v_periodo_fiscal_fin
   and prov.fec_pago >= v_periodo_fiscal_ini
   and a.estado = 'N'
   --outter join para las retenciones que no estan en las retenciones virtuales.
   and a.cod_proveedor = rv.cod_proveedor(+)
   and a.nro_factura = rv.nro_factura(+)
   and a.fec_pago = rv.fec_pago(+);

 ----Retenciones Clientes
  insert into cb_lib_retencion(
      nro_factura, nro_timbrado,
      fec_pago,cod_persona,
      nom_completo,ruc_retenido, ruc_proveedor,
      nro_com_retencion, fec_com_retencion,
      mto_ret_renta, mto_ret_iva,
      imp_ret_renta, imp_ret_iva, procesado,
      mto_exento, imp_ret_exento)
   select ret.nro_factura, fub_obt_nro_timbrado('I',fug_obt_ofi_cliente(cli.cod_persona)), 
          ret.fec_retencion,
          clie.cod_persona, 
          clie.nom_completo,
          nvl(substr(clie.nro_documento, 1, instr(clie.nro_documento, '-') -1),0) ruc_retenido,
          substr(clie.nro_documento, instr(clie.nro_documento, '-') + 1, length(clie.nro_documento) - instr(clie.nro_documento, '-')) ruc_digito,
          nvl(SUBSTR(LPAD(cli.nro_ret_tesaka,13,'0'),1,3),'999')||'-'||nvl(SUBSTR(LPAD(cli.nro_ret_tesaka,13,'0'),4,3),'999')
          ||'-'||nvl(SUBSTR(LPAD(cli.nro_ret_tesaka,13,'0'),7,7),'9999999'),
           ret.fec_pago,
          pag_gen.FU_CON_MON_A_MONEDA(ret.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,ret.mto_renta,ret.cotizacion),
          0 monto_iva,
          pag_gen.FU_CON_MON_A_MONEDA(ret.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,ret.mto_ret_renta,ret.cotizacion),
          pag_gen.FU_CON_MON_A_MONEDA(ret.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,ret.mto_retencion,ret.cotizacion) monto_retencion, 'N',
          pag_gen.FU_CON_MON_A_MONEDA(ret.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,ret.mto_factura,ret.cotizacion),
          pag_gen.FU_CON_MON_A_MONEDA(ret.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,ret.mto_retencion,ret.cotizacion)
     from ge_inr_retenciones ret, ba_personas clie,ge_ret_vir_clientes cli
    where ret.cod_persona = clie.cod_persona
       and ret.fec_retencion  between v_periodo_fiscal_ini and  v_periodo_fiscal_fin
       and cli.estado = 'G'
       and ret.cod_persona = cli.cod_persona
       and ret.nro_factura = cli.nro_factura
       and ret.fec_retencion = cli.fec_pago;



   -- Verificamos la cantidad de registros del periodo
   select  count(*)
     into v_cant_reg
     from cb_lib_retencion
    where fec_com_retencion between v_periodo_fiscal_ini and  v_periodo_fiscal_fin
      and procesado ='N';

   -- obtenemos la cantidad de archivos a generar
   -- en cada archivo se genera hasta 15 mil registros
   if ceil(v_cant_reg / 15000) > 1 then
     v_cant_arc := ceil(v_cant_reg / 15000);
   else
     v_cant_arc := 1;
   end if;
   for i in 1..v_cant_arc loop
      if i = 1 then
         -- generamos el archivo que contiene los datos
         v_archivo := UTL_FILE.FOPEN( v_directorio, 'LIB_RET_'||to_char(v_fec_arc,'MONYYYY')||'.TXT', 'w'  );
         --pag_arc.fu_arc_abrir( v_directorio, 'LIB_RET_'||to_char(v_fec_arc,'MONYYYY')||'.TXT', 'w' );
      else
         -- generamos el archivo que contiene los datos de la financiera
         v_archivo := UTL_FILE.FOPEN( v_directorio, 'LIB_RET_'||to_char(v_fec_arc,'MONYYYY')||'.TXT', 'w'  );
         --pag_arc.fu_arc_abrir( v_directorio, 'LIB_RET'||i||'_'||to_char(v_fec_arc,'MONYYYY')||'.TXT', 'w' );
      end if;
      -- generamos el archivo que contiene los datos
      LP_GEN_DAT_CABECERA(v_archivo, v_periodo_fiscal_ini, v_periodo_fiscal_fin,14999);
      -- obtener y generar datos para el detalle
      LP_GEN_DAT_DETALLE(v_archivo, v_periodo_fiscal_ini, v_periodo_fiscal_fin,14999);

      pag_arc.pr_arc_cerrar( v_archivo );
   end loop;
   --- Actualizar a procesado el cb_lib_retencion original
   update cb_lib_retencion v
      set procesado = 'S'
    where exists (select 1 from cb_lib_retencion t
                   where t.nro_factura = v.nro_factura
                     and t.nro_timbrado = v.nro_timbrado)
      and procesado = 'N';
END prb_lib_ret_ascii;
/

