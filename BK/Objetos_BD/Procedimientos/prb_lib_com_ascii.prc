CREATE OR REPLACE PROCEDURE IT.PRB_LIB_COM_ASCII IS
  /* Procediemto: Genera archivos a partir de la tabla de ventas */
  /* IT --> 28/oct/2007 */
  v_directorio VARCHAR2(30);
  v_archivo       UTL_FILE.FILE_TYPE;
  con NUMBER :=0;
  v_cant_reg number :=0;
  v_cant_arc number :=0;
  v_periodo_fiscal_ini ge_calendarios.fec_actual%type;
  v_periodo_fiscal_fin ge_calendarios.fec_actual%type;
  v_fec_arc ge_calendarios.fec_actual%type;

  v_sentencia varchar2(150) := 'TRUNCATE TABLE cb_lib_compras_tmp';
  v_error varchar2(3000);

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

-- obtener y generar datos para Nota de Credito
PROCEDURE LP_GEN_NOT_CREDITO(p_archivo in UTL_FILE.FILE_TYPE,
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
   v_total_devengado       number(18) :=0;
   v_cont_reg              number :=0;
   cursor acumula_factura is
   select l.fecha,
          l.nro_factura,
          l.nro_timbrado,
          nvl(l.mto_exento,0) mto_exento,
          nvl(l.mto_gravado_10,0) mto_gravado_10,
          nvl(l.mto_gravado_5,0) mto_gravado_5,
          l.can_cuota
     from cb_lib_compras_tmp  l
    where l.fecha between p_periodo_fiscal_ini and  p_periodo_fiscal_fin
      and procesado = 'N'
      and rownum <= p_can_reg_gen
    order by fecha, nro_factura;

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
    -- acumulamos exentas, grav10 y gra5
    -- en la tabla se almacena iva incluido x lo tanto no es necesario sumar el impuesto
    for i in acumula_factura loop
       begin
         v_total_devengado := v_total_devengado + (i.mto_exento + i.mto_gravado_10 + i.mto_gravado_5);
         v_cont_reg        := v_cont_reg + 1;
         -- actualizamos estos registros con un flag en lib ventas para generar los datos de estos mismos en el detalle
         begin
           update cb_lib_compras_tmp
              set procesado = 'X'
            where nro_factura  = i.nro_factura
              and nro_timbrado = i.nro_timbrado
              and fecha        = i.fecha
              and procesado    = 'N';
          exception
             when others then
                null;
         end;
       end;
    end loop;
    v_registro := '1'||CHR(09)||   -- tipo de registro
                  to_char(p_periodo_fiscal_ini, 'yyyymm')||CHR(09)|| -- periodo aaaammm
                  '1'||CHR(09)||  -- tipo de reporte 1= original; 2= Rectificativa
                  '911'||CHR(09)|| -- tipo de informe, es constante 911
                  '211'||CHR(09)|| -- cod. formulario - libro de ventas
                  substr(v_ruc_entidad, 1,instr(v_ruc_entidad,'-')-1)||CHR(09)|| -- ruc de brios
                  substr(v_ruc_entidad, instr(v_ruc_entidad,'-')+1, length(v_ruc_entidad) - instr(v_ruc_entidad,'-'))||CHR(09)|| -- dv
                  substr(v_nom_entidad,1,80)||CHR(09)|| -- razon social
                  v_ruc_representante||CHR(09)|| -- ruc representante legal
                  fue_obt_ruc_dig_verificador(v_ruc_representante)||CHR(09)|| -- dv rep legal
                  substr(v_nom_representante,1,80)||CHR(09)|| -- nom representante legal
                  v_cont_reg||CHR(09)|| -- cantidad de reg reportados en el detall
                  v_total_devengado||CHR(09)||  -- total gra10 + grav5 + exe
                  'NO'||CHR(09)|| -- exportador SI o NO, a partir de enero09 iag
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
   v_registro2     varchar2(300);
   -- cursor para generar detalle
   cursor detalle is
   select Decode(ltrim(rtrim(t.raz_social)), 'SIN NOMBRE' ,'IMPORTES CONSOLIDADOS',t.raz_social) nombre,
          decode(t.nro_documento,'X','44444401',t.nro_documento) DOCUMENTO,
          t.fecha,
          t.nro_factura,
          t.nro_timbrado,
          t.tipo,
          t.cod_persona,
          nvl(t.mto_exento,0) mto_exento,
          nvl(t.mto_gravado_10,0) mto_gravado_10,
          nvl(t.mto_gravado_5,0) mto_gravado_5,
          nvl(t.impuesto_10,0) impuesto_10,
          nvl(t.impuesto_5,0) impuesto_5,
          decode(t.tip_compra,'CO','1','CR','2') con_compra,
          t.can_cuota
     from cb_lib_compras_tmp t
    where t.fecha between p_periodo_fiscal_ini and  p_periodo_fiscal_fin
      and procesado = 'X' -- este es el estado en el que dejamos los registros a ser procesado en el archivo
      AND t.tipo = '2'
      and rownum <= p_can_reg_gen
    order by fecha, nro_factura;

BEGIN
  for j in detalle loop
   v_registro2 := 2||chr(09)|| -- tipo de registro
                 j.documento||chr(09)|| -- RUC cliente
                 fue_obt_ruc_dig_verificador(to_char(j.documento))||chr(09)|| -- DV cliente
                 j.nombre||chr(09)|| -- Nombre o Razon Social
                 j.nro_timbrado||chr(09)|| -- Nro. de Timbrado
                 1||chr(09)|| -- tipo de doc - 1=Fact de ventas; 2= ND; 3=NC
                 J.Nro_Factura||chr(09)|| -- nro factura
                 to_char(j.fecha,'dd/mm/yyyy')||chr(09)|| -- fecha factura
                 j.mto_gravado_10||chr(09)|| -- razon social
                 j.impuesto_10||chr(09)|| -- ruc representante legal
                 j.mto_gravado_5||chr(09)|| -- dv rep legal
                 j.impuesto_5||chr(09)|| -- nom representante legal
                 j.mto_exento||chr(09)|| -- cantidad de reg reportados en el detall
                 0||chr(09)||
                 j.con_compra||chr(09)||
                 j.can_cuota;
                  
     pag_arc.pr_arc_escribir(v_registro2, p_archivo);
     con := con + 1;
     -- actualizamos el flag en cb_lib_compras_tmp para que no tome en la otra generacion
     update cb_lib_compras_tmp
        set procesado = 'S'
      where fecha        = j.fecha
        and nro_factura  = j.nro_factura
        and nro_timbrado = j.nro_timbrado
        and procesado    = 'X';
  end loop;
END;

--> Agregado el 06/05/2008 IT
-- generamos notas de creditos para el periodo
PROCEDURE LP_GEN_NOT_CREDITO(p_archivo in UTL_FILE.FILE_TYPE,
                             p_periodo_fiscal_ini in date,
                             p_periodo_fiscal_fin in date,
                             p_can_reg_gen in number )
IS
   v_registro3     varchar2(249);
   -- cursor para generar detalle
   cursor nota_credito is
   select Decode(ltrim(rtrim(t.raz_social)), 'SIN NOMBRE' ,'IMPORTES CONSOLIDADOS',t.raz_social) nombre,
          decode(t.nro_documento,'X','44444401',t.nro_documento) DOCUMENTO,
          t.fecha, --fecha en q se genero la nc
          t.nro_factura, -- nro de nc generada
          t.nro_timbrado,
          t.tipo,
          t.cod_persona,
          nvl(t.mto_exento,0) mto_exento,
          case
             when nvl(t.impuesto_10,0) = 0 and nvl(t.mto_gravado_10,0) > 0 then
                t.mto_gravado_10
             when nvl(t.mto_gravado_10,0) < 0  then
                (t.mto_gravado_10 * 0)
          else
             (nvl(t.impuesto_10,0) * 10)
          end mto_gravado_10, -- calculamos en base al impuesto
          case
             when nvl(t.impuesto_10,0) <0 then -- si es menor a cero, dejamos en cero Modif. 25/04/2008
                (impuesto_10 * 0)
          else
             nvl(t.impuesto_10,0)
          end  impuesto_10,
          case
             when nvl(t.impuesto_5,0) = 0 and nvl(t.mto_gravado_5,0) > 0 then
                t.mto_gravado_5
             when nvl(t.mto_gravado_5,0) < 0 then -- si es menor a cero, dejamos en cero Modif. 25/04/2008
                ( t.mto_gravado_5 * 0)
          else
             round(nvl(t.impuesto_5,0) * 20)
          end mto_gravado_5, -- calculamos en base al impuesto
          case
             when round(nvl(t.impuesto_5,0)) < 0 then -- si es menor a cero, dejamos en cero Modif. 25/04/2008
                (impuesto_5 * 0)
          else
             impuesto_5
          end impuesto_5,
		  decode(t.tip_compra,'CO','1','CR','2') con_compra,
          t.can_cuota
     from cb_lib_compras_tmp t
    where t.fecha between p_periodo_fiscal_ini and p_periodo_fiscal_fin
    and procesado = 'X' -- este es el estado en el que dejamos los registros a ser procesado en el archivo
    AND t.tipo='3'
    and rownum <= p_can_reg_gen;

BEGIN
for x in nota_credito loop

   v_registro3 := 2||chr(09)|| -- tipo de registro
                 x.documento||chr(09)|| -- RUC cliente
                 fue_obt_ruc_dig_verificador(to_char(x.documento))||chr(09)|| -- DV cliente
                 x.nombre||chr(09)|| -- Nombre o Razon Social
                 x.nro_timbrado||chr(09)|| -- Nro. de Timbrado
                 3||chr(09)|| -- tipo de doc - 1=Fact de ventas; 2= ND; 3=NC
                 x.Nro_Factura||chr(09)|| -- nro factura
                 to_char(x.fecha,'dd/mm/yyyy')||chr(09)|| -- fecha factura
                 x.mto_gravado_10||chr(09)|| -- razon social
                 x.impuesto_10||chr(09)|| -- ruc representante legal
                 x.mto_gravado_5||chr(09)|| -- dv rep legal
                 x.impuesto_5||chr(09)|| -- nom representante legal
                 x.mto_exento||chr(09)|| -- cantidad de reg reportados en el detall
                 0||chr(09)||
                 x.con_compra||chr(09)||
                 x.can_cuota;

				 
  pag_arc.pr_arc_escribir(v_registro3, p_archivo);
  con := con + 1;
    -- actualizamos el flag en cb_lib_compras_tmp para que no tome en la otra generacion
     update cb_lib_compras_tmp
        set procesado = 'S'
      where fecha        = x.fecha
        and nro_factura  = x.nro_factura
        and nro_timbrado = x.nro_timbrado
        and procesado    = 'X';
 end loop;

END;
--------- Proceso Principal --------------
BEGIN
   --v_directorio :='/u02/oradata/it/utl';
   v_directorio :='/oradata/utl';
   -------------------------------------------------------------------------------------------
   /*Primero truncamos la tabla TMP para poder insertar los datos a procesar*/
   -------------------------------------------------------------------------------------------
   sql_util.ejecute_dml(v_sentencia, v_error);
   -- recuperamos el periodo fiscal a partir del calendario
    select g.pri_dia_mes,      g.ult_dia_mes
      into v_periodo_fiscal_ini,v_periodo_fiscal_fin
      from ge_calendarios g
     where g.cod_modulo = 1; -- general
   -- seteo al mes anterior, se procesa por mes cerrado
   v_periodo_fiscal_ini := add_months(v_periodo_fiscal_ini,-1);
   v_periodo_fiscal_fin := add_months(v_periodo_fiscal_fin,-1);
   ---
   v_fec_arc := v_periodo_fiscal_fin;

   -- cargamos los datos en la tabla temporal
   insert into cb_lib_compras_tmp(
      nro_factura, nro_timbrado, fecha,
      tipo, cod_persona, raz_social,  nro_documento,
      mto_exento, mto_gravado_5, mto_gravado_10, impuesto_5, impuesto_10,
      procesado, cod_ofi_origen, cod_ent_proveedor,tip_compra, can_cuota)
   select nro_factura, nro_timbrado, fecha,
      '2', nvl(cod_persona,'0'),  raz_social,  nvl(substr(nro_documento, 1,instr(nro_documento,'-')-1),nro_documento),
      mto_exento, mto_gravado_5, mto_gravado_10, impuesto_5, impuesto_10,
      'N',1 AS cod_ofi_origen,cod_ent_proveedor,tipo, can_cuota
    from cb_lib_compras
   where fecha  between v_periodo_fiscal_ini and  v_periodo_fiscal_fin
   and nvl(procesado,'N') = 'N'
   UNION ALL
     select v.nro_factura, v.nro_timbrado, v.fecha,
      '3', nvl(v.cod_persona,'0'), v.nom_completo, TRIM(translate(v.nro_documento,'ABCDEFGHIJKLMNÑOPQRSTUVWXYZ-|°@¬!"#$%&/\()=?¡¿*¨{}^`[]_:;,.~><+abcdefghijklmnñopqrstuvwxyz',' ')),
      v.mto_exento_gs, v.mto_gravado_5_gs, v.mto_gravado_10_gs, v.impuesto_5_gs, v.impuesto_10_gs, -- DYDMR-5467 Nov/2016 NAF
      'N',1 AS cod_ofi_origen, 0,v.tip_venta, can_cuota
    from cb_lib_ventas v
   where fecha  between v_periodo_fiscal_ini and  v_periodo_fiscal_fin
   and v.tip_comprobante = 'N' --nota de credito ventas
   and v.procesado = 'N';
      
-- Verificamos la cantidad de registros del periodo
   select  count(*)
     into v_cant_reg
     from cb_lib_compras_tmp l
    where l.fecha between v_periodo_fiscal_ini and  v_periodo_fiscal_fin
      and l.procesado ='N';
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
         v_archivo := pag_arc.fu_arc_abrir( v_directorio, 'LIB_COMP_'||to_char(v_fec_arc,'MONYYYY')||'.TXT', 'w' );
      else
         -- generamos el archivo que contiene los datos
         v_archivo := pag_arc.fu_arc_abrir( v_directorio, 'LIB_COMP'||i||'_'||to_char(v_fec_arc,'MONYYYY')||'.TXT', 'w' );
      end if;
      -- generamos el archivo que contiene los datos de la financiera
      LP_GEN_DAT_CABECERA(v_archivo, v_periodo_fiscal_ini, v_periodo_fiscal_fin,14999);
      -- obtener y generar datos para el detalle
      LP_GEN_DAT_DETALLE(v_archivo, v_periodo_fiscal_ini, v_periodo_fiscal_fin,14999);
      --  NOTA DE CREDITO
      LP_GEN_NOT_CREDITO(v_archivo, v_periodo_fiscal_ini, v_periodo_fiscal_fin,14999);
      pag_arc.pr_arc_cerrar( v_archivo );
   end loop;
   --- Actualizar a procesado el cb_lib_compras original
   update cb_lib_compras v
      set procesado = 'S'
    where exists (select 1 from cb_lib_compras_tmp t
                   where t.nro_factura = v.nro_factura
                     and t.nro_timbrado = v.nro_timbrado)
      and procesado = 'N';
   --- Actualizar a procesado el cb_lib_ventas 
   update cb_lib_ventas c
      set procesado = 'S'
    where exists (select 1 from cb_lib_compras_tmp t
                   where t.nro_factura = c.nro_factura
                     and t.nro_timbrado = c.nro_timbrado)
      and procesado = 'N'; 
EXCEPTION 
  when others then 
     raise_application_error(-20000,'Error Libro de Compras.'||sqlerrm);
END prb_lib_com_ascii;
/

