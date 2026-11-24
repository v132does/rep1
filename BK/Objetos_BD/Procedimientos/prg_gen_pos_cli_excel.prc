CREATE OR REPLACE PROCEDURE IT.PRG_GEN_POS_CLI_EXCEL
 (P_COD_CLIENTE IN GE_CLIENTES.COD_PERSONA%TYPE DEFAULT NULL,
  P_COD_AUDITOR IN BA_PERSONAS.COD_PERSONA%TYPE DEFAULT NULL,
  P_FECHA       IN date,
  P_OBSERVACION   IN VARCHAR2,
  P_RESPUESTA IN OUT VARCHAR, 
  P_NOM_AUDITOR IN VARCHAR2,
  P_TEL_AUDITOR IN VARCHAR2,
  P_COD_DIR_AUDITOR IN VARCHAR2,
  P_MAIL_AUDITOR IN VARCHAR2
 )
 IS
  myexcelcontent CLOB;
  --Directorio configurado en BD
  g_repository         VARCHAR2(100) := fug_obt_pardinamico('DIR_REP_FTP');
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_ip                 VARCHAR2(100) := '192.168.254.136';
  g_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port               VARCHAR2(100) := '21';
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
	 --g_user               VARCHAR2(100) := 'ftpramail';
  g_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
	 --g_pass               VARCHAR2(100) := 'kacha.ma1';
  g_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  g_extractos          VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_EXTRACTOS');

 
  v_respuesta        VARCHAR2(4000);




   /* Prepara el documento XML formato Excel. */
   PROCEDURE lp_abr_archivo
   (
      v_xml_body IN OUT NOCOPY CLOB
   );

   /* Cierra el documento XML formato Excel. */
   PROCEDURE lp_cie_archivo
   (
      v_xml_body IN OUT NOCOPY CLOB
   );   

   /* Crea la nueva hoja a escribir */
   PROCEDURE lp_abr_hoja
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_NOM_HOJA VARCHAR2
   );

   /* Cierra la nueva hoja a escribir */
   PROCEDURE lp_cie_hoja
   (
      v_xml_body IN OUT NOCOPY CLOB
   );

   /* Define las columnas del archivo */
   PROCEDURE lp_def_columnas
   (
      v_xml_body IN OUT NOCOPY CLOB
   );

   /* Crea la cabecera del informe (LUGAR DEL LOGO) */
   PROCEDURE lp_gen_cab_logo
   (
      v_xml_body IN OUT NOCOPY CLOB
   );

   /* Crea la cabecera del informe (LUGAR DE la fecha) */
   PROCEDURE lp_gen_cab_fecha
   (
      v_xml_body IN OUT NOCOPY CLOB,
      v_fecha varchar2
   );
   /* saltos de fila*/
   PROCEDURE lp_ins_filas
   (
      v_xml_body IN OUT NOCOPY CLOB
   );

   
   /*saltos de fila en tabla*/
   PROCEDURE lp_ins_filas_tab
   (
      v_xml_body IN OUT NOCOPY CLOB
   );  


 
   /* inserta destinatario*/
   PROCEDURE lp_ins_destinatario
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_NOM_AUDITOR VARCHAR2,
      V_DIR_AUDITOR VARCHAR2,
      V_TEL_AUDITOR VARCHAR2
   );   


   /* inserta referencia*/
   PROCEDURE lp_ins_referencia
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_NOM_EMPRESA VARCHAR2
   );

   /* inserta inicio de mensaje*/
   PROCEDURE lp_ins_ini_informe
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_NOM_EMPRESA VARCHAR2,
      V_FEC_SALDO VARCHAR2
   );

   PROCEDURE lp_ins_det_informe
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_FEC_SALDO VARCHAR2
   );

   /* fin de informe*/
   PROCEDURE lp_ins_fin_informe
   (
      v_xml_body IN OUT NOCOPY CLOB
   );

   /* inserta título tipo cuenta en el detalle*/
   PROCEDURE lp_ins_tipo_cuenta
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_DES_TIP_CTA VARCHAR2
   );   

   /* inserta título tipo cuenta en el detalle*/
   PROCEDURE lp_ins_det_cuenta
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_DES_CTA VARCHAR2,
      V_DES_MONEDA VARCHAR2,
      V_NRO_CUENTA VARCHAR2,
      V_SALDO  NUMBER,
      V_TASA NUMBER,
      V_FEC_APERTURA VARCHAR2,
      V_FEC_VENCIMIENTO VARCHAR2
   );   

   /* inserta firmantes de cuentas*/
   PROCEDURE lp_ins_fir_cuenta
   (
      v_xml_body IN OUT NOCOPY CLOB
   );  

   /* inserta firmantes de cuentas*/
   PROCEDURE lp_ins_firmante
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_NOMBRE VARCHAR2,
      V_CARGO VARCHAR2
   ); 


   /*Escribe el archivo XML*/
   PROCEDURE lp_cre_xml
     (
          p_filename IN VARCHAR2,
          p_dir      IN VARCHAR2,
          p_clob     IN CLOB
     ) ;

   /*Escribe el archivo XML agrega el detalle al archivo (no reescribe)*/
   PROCEDURE lp_cre_xml_add
     (
          p_filename IN VARCHAR2,
          p_dir      IN VARCHAR2,
          p_clob     IN CLOB
     ) ;













      v_nom_empresa varchar2(1200);
      v_nom_auditor varchar2(1200);
      v_dir_auditor varchar2(1200);
      v_tel_auditor varchar2(1200);
      v_Fecha varchar2(1200) := 'Asunción 04 de mayo del 2015';
      v_aux number := 1;--control de orden
      cursor c_cuentas is
      /*CUENTAS VISTAS CTA CORRIENTE Y AHORRO*/
      Select 1 ORDEN,
             mad.descripcion,
             mad.cod_modalidad,
             ext.cod_moneda,
             cta.nro_cuenta,
             ext.sal_actual saldo,
             ext.tas_nominal,
             c.fec_apertura,
             c.fec_vencimiento,
             'CUENTAS CORRIENTES' DES_TIPO
      from ge_cta_clientes cta,
           Ge_Ext_Cli_Cuentas ext,
           ge_cuentas c,
           ge_modalidades mad

      where cta.nro_cuenta = ext.nro_cuenta
      and   cta.cod_persona = ext.cod_persona
      and   cta.cod_persona = P_COD_CLIENTE
      and   ext.fec_extracto = P_FECHA
      and   cta.nro_cuenta = c.nro_cuenta
      and   mad.cod_modalidad = ext.cod_modalidad
      and   mad.cod_modulo != 6
      and   cta.cod_modulo = '4'

      union all
      Select 1.1 ORDEN,
             mad.descripcion,
             mad.cod_modalidad,
             ext.cod_moneda,
             cta.nro_cuenta,
             ext.sal_actual saldo,
             ext.tas_nominal,
             c.fec_apertura,
             c.fec_vencimiento,
             'CUENTAS AHORROS' DES_TIPO
      from ge_cta_clientes cta,
           Ge_Ext_Cli_Cuentas ext,
           ge_cuentas c,
           ge_modalidades mad

      where cta.nro_cuenta = ext.nro_cuenta
      and   cta.cod_persona = ext.cod_persona
      and   cta.cod_persona = P_COD_CLIENTE
      and   ext.fec_extracto = P_FECHA
      and   cta.nro_cuenta = c.nro_cuenta
      and   mad.cod_modalidad = ext.cod_modalidad
      and   mad.cod_modulo != 6
      and   cta.cod_modulo = '3'

      union all
      /*PRESTAMOS SAL CAPITAL*/
      select 2 ORDEN,
             r.descripcion,
             i.cod_modalidad,
             i.cod_moneda,
             d.nro_cuenta,
             d.Sal_Actual, --ext.sal_actual,
             ext.tas_nominal,
             p.fec_apertura,
             p.fec_vencimiento,
             'PRESTAMOS'

        from cb_sal_inventarios_his     i,
             cb_sal_inventarios_det_his d,
             ge_cuentas                 p,
             cb_rubros                  r,
             Ge_Ext_Cli_Cuentas         ext,
             ge_modalidades             mad
       where i.nro_referencia = d.nro_referencia
         and i.fecha = d.fecha
         and d.nro_cuenta = p.nro_cuenta
         and p.nro_cuenta = ext.nro_cuenta     
         and i.cod_rubro = r.cod_rubro(+)
         and not exists (select 1
                from ba_cod_referencias
               where dominio = 'COD_RUB_CHE_VAL_CUS'
                 and val_minimo = i.cod_rubro)
         and ext.cod_persona = P_COD_CLIENTE
         and i.fecha = P_FECHA
         and i.tip_saldo in ('C','F')--capital y AFD --dydmr-6633 - 17/07/2017
         and ext.nro_cuenta = d.nro_cuenta
         and ext.fec_extracto = i.fecha
         and mad.cod_modalidad = ext.cod_modalidad
         and mad.cod_modulo = 6

      union all
      /*PRÉSTAMOS INTERES*/
      select 2 ORDEN,
             'INTERES',
             i.cod_modalidad,
             i.cod_moneda,
             d.nro_cuenta,
             d.Sal_Actual, --ext.sal_actual,
             ext.tas_nominal,
             p.fec_apertura,
             p.fec_vencimiento,
             'PRESTAMOS'

        from cb_sal_inventarios_his     i,
             cb_sal_inventarios_det_his d,
             ge_cuentas                 p,
             cb_rubros                  r,
             Ge_Ext_Cli_Cuentas         ext,
             ge_modalidades             mad
       where i.nro_referencia = d.nro_referencia
         and i.fecha = d.fecha
         and d.nro_cuenta = p.nro_cuenta
         and p.nro_cuenta = ext.nro_cuenta  
         and i.cod_rubro = r.cod_rubro(+)
         and not exists (select 1
                from ba_cod_referencias
               where dominio = 'COD_RUB_CHE_VAL_CUS'
                 and val_minimo = i.cod_rubro)
         and ext.cod_persona = P_COD_CLIENTE
         and i.fecha = P_FECHA
         and i.tip_saldo = 'I'--interes
         and ext.nro_cuenta = d.nro_cuenta
         and ext.fec_extracto = i.fecha
         and mad.cod_modalidad = ext.cod_modalidad
         and mad.cod_modulo = 6

      union all

     /*GARANTÍAS*/
      select 
             3 Orden,
             ti.descripcion,
             ti.cod_modalidad,
             a.cod_moneda,
             to_char(a.nro_garantia),
             a.valor,
             0 tasa,
             a.fec_inicio,
             a.fec_vencimiento,
             'GARANTIAS'
                 
      from pr_garantias a, pr_gar_tipos ti, ge_clientes cli
      where cli.cod_persona = a.cod_persona
      and ti.cod_garantia = a.cod_garantia
      and cli.cod_persona = P_COD_CLIENTE
      and a.fec_inicio <= sysdate
      and a.estado = 'C'

      /*COMEX*/
      union all
      Select 4 ORDERN,
             mo.descripcion des_modalidad,
             mo.cod_modalidad,
             e.cod_moneda,
             o.nro_cuenta,
             o.saldo saldo,
             0,
             o.fec_insercion,
             o.fec_vencimiento,
             'COMERCIO EXTERIOR'
                  
                 
            from cx_cta_importaciones  o,
                 ge_cuentas      e,
                 ge_cta_clientes c,
                 ba_personas     p,
                 ge_clientes     cli,
                 
                 ge_modalidades  mo
           where o.nro_cuenta = c.nro_cuenta
             and o.nro_cuenta = e.nro_cuenta
             and c.relacion = 'P'
             and nvl(o.saldo, 0) > 0
             and c.cod_persona = p.cod_persona
             and cli.cod_persona = c.cod_persona
           
             and mo.cod_modulo = e.cod_modulo
             and mo.cod_modalidad = e.cod_modalidad
             and cli.cod_persona = P_COD_CLIENTE
             and o.saldo > 0

      union all
      /*TARJETAS*/
      select     
             5 ORDERN,
             q.descripcion,
             q.cod_modalidad,
             k.cod_moneda,
             k.nro_cuenta,
             k.sal_procesadora saldo,
             0 tas_nominal,
             k.fec_apertura,
             k.fec_cancelacion,
             'TARJETAS' 

          
            from ge_clientes     x,
                 ba_personas     y,
               
                 ta_cta_tarjetas k,
                 ge_cta_clientes n,
                 ge_modalidades  q
           where y.cod_persona = x.cod_persona
             and n.nro_cuenta = k.nro_cuenta
             and n.relacion = 'P'
             and n.cod_persona = y.cod_persona
             and k.estado <> 'C'
             and q.cod_modulo = k.cod_modulo
             and q.cod_modalidad = k.cod_modalidad
             and x.cod_persona = P_COD_CLIENTE

      /*CAJAS DE SEGURIDAD*/
      union all
      Select 6 ORDERN,
             g.descripcion,
             g.cod_modalidad,
             c.cod_moneda,
             c.nro_contrato,
             0 saldo,
             0 tas_nominal,
             c.fec_apertura,
             null fec_vencimiento,
             'CAJAS DE SEGURIDAD'
      from cs_contratos c,
           cs_con_personas cp,
           ge_modalidades g
      where c.nro_contrato = cp.nro_contrato
      and   cp.cod_persona = P_COD_CLIENTE
      and   g.cod_modalidad = 16

      ORDER BY 1,5,6 desc;  


   /*CURSOR DE FIRMANTES*/
   cursor c_firmantes is
   select 
      DISTINCT
      b.cod_persona,
      p.nom_completo,
      b.relacion,
      r.significado des_relacion

      from
      (Select  cta.cod_persona,
                 cta.nro_cuenta
          from ge_cta_clientes cta,
               Ge_Ext_Cli_Cuentas ext,
               ge_modalidades mad

          where cta.nro_cuenta = ext.nro_cuenta
          and   cta.cod_persona = ext.cod_persona
          and   cta.cod_persona = P_COD_CLIENTE
          and   ext.fec_extracto = P_FECHA
          and   mad.cod_modalidad = ext.cod_modalidad
          )a,
          ge_cta_clientes b,    
          Ba_Cod_Referencias R,
          BA_PERSONAS P
    where a.cod_persona != b.cod_persona
    and   a.nro_cuenta = b.nro_cuenta
    and   r.val_minimo = b.relacion
    and   r.dominio = 'AST_RELACION'
    and   p.cod_persona = b.cod_persona;


   /* Prepara el documento XML formato Excel. */
   PROCEDURE lp_abr_archivo
   (
      v_xml_body IN OUT NOCOPY CLOB
   )  
   IS
   BEGIN
    v_xml_body := '<?xml version="1.0" encoding="ISO-8859-9"?>'                                   || chr(10) ||
                        '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"'           ||chr(10) ||
                        'xmlns:o="urn:schemas-microsoft-com:office:office"'                        ||chr(10) ||
                        'xmlns:x="urn:schemas-microsoft-com:office:excel"'                         ||chr(10) ||
                        'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"'                  ||chr(10) ||
                        'xmlns:html="http://www.w3.org/TR/REC-html40">'                            ||chr(10) ||
                        '<ExcelWorkbook xmlns="urn:schemas-microsoft-com:office:excel">'           ||chr(10) || 
                        '<WindowHeight>8580</WindowHeight>'                                        ||chr(10) || 
                        '<WindowWidth>15180</WindowWidth>'                                         || chr(10) ||
                        '<WindowTopX>120</WindowTopX>'                                             || chr(10) ||
                        '<WindowTopY>45</WindowTopY>'                                              || chr(10) ||
                        '<ProtectStructure>False</ProtectStructure>'                               || chr(10) ||
                        '<ProtectWindows>False</ProtectWindows>'                                   || chr(10) ||
                        '</ExcelWorkbook>'                                                         || chr(10) || 
                        '<Styles>'                                                                 || chr(10) ||


                        '<Style ss:ID="Default" ss:Name="Normal">'                                 || chr(10) ||
                        '<Alignment ss:Vertical="Bottom"/>'                                        || chr(10) ||
                        '<Borders/>'                                                                || chr(10) || 
                        '<Font/>'                                                                  || chr(10) ||
                        '<Interior/>'                                                              || chr(10) || 
                        '<NumberFormat/>'                                                          || chr(10) ||
                        '<Protection/>'                                                            || chr(10) || 
                        '</Style>'                                                                 || chr(10) ||
                        
                         '<Style ss:ID="s16" ss:Name="Millares">'                                  || chr(10) ||
                         '<NumberFormat ss:Format="_(* #,##0.00_);_(* \(#,##0.00\);_(* &quot;-&quot;??_);_(@_)"/>'|| chr(10) ||
                         '</Style>'                                                                || chr(10) ||                  
                                                                                                   
                        '<Style ss:ID="s22">'                                                      || chr(10) ||
                        '<Font x:Family="Swiss" ss:Bold="1" ss:Underline="Single"/>'               ||chr(10) || 
                        '</Style>'                                                                 || chr(10) ||

 
                        '<Style ss:ID="s62">'                                                      || chr(10) || 
                       
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Color="#000000" ss:Bold="1"/>'|| chr(10) || 
                        
                        '</Style>'                                                                 || chr(10) ||  
                         
                        '<Style ss:ID="s67">'                                                      || chr(10) ||
                         '<Alignment ss:Horizontal="Center" ss:Vertical="Bottom"/>'                || chr(10) ||
                         '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="11" ss:Color="#000000"/>'|| chr(10) ||
                        '</Style>'                                                                        || chr(10) ||
                        '<Style ss:ID="s68">'                                                             || chr(10) ||
                         '<Alignment ss:Horizontal="Justify" ss:Vertical="Center"/>'                      || chr(10) ||
                         '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="11" ss:Color="#000000"/>'   || chr(10) ||
                        '</Style>'                                                                        || chr(10) ||   
                        '<Style ss:ID="s69">'                                                             || chr(10) ||
                         '<Alignment ss:Horizontal="Left" ss:Vertical="Center"/>'                         || chr(10) ||
                         '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="11" ss:Color="#000000"'     || chr(10) ||
                          'ss:Underline="Single"/>'                                                       || chr(10) ||   
                        '</Style>'                                                                        || chr(10) ||
                        '<Style ss:ID="s70">'                                                             || chr(10) ||
                         '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="11" ss:Color="#000000"'     || chr(10) ||
                          'ss:Bold="1"/>'                                                                 || chr(10) ||
                        '</Style>'                                                                        || chr(10) ||

                        '<Style ss:ID="s63">'                                                             || chr(10) ||
                        '<Alignment ss:Horizontal="Left" ss:Vertical="Top" ss:WrapText="1"/>'             || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="11" ss:Color="#000000"/>'    || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||
                       '<Style ss:ID="s65">'                                                              || chr(10) ||
                        '<Alignment ss:Horizontal="Right" ss:Vertical="Bottom"/>'                         || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="11" ss:Color="#000000"/>'    || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||
                       '<Style ss:ID="s72">'                                                              || chr(10) ||
                       '<Alignment ss:Horizontal="Left" ss:Vertical="Center"/>'                           || chr(10) ||
                       '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="11" ss:Color="#000000"/>'     || chr(10) ||
                      '</Style>'                                                                          || chr(10) ||    
                      '<Style ss:ID="s74">'                                                               || chr(10) ||    
                       '<Alignment ss:Horizontal="Left" ss:Vertical="Center" ss:WrapText="1"/>'           || chr(10) ||
                       '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="11" ss:Color="#000000"/>'     || chr(10) ||
                      '</Style>'                                                                          || chr(10) ||
                      '<Style ss:ID="s75">'                                                               || chr(10) ||
                       '<Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>'         || chr(10) ||
                       '<Borders>'                                                                        || chr(10) ||
                        '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>'          || chr(10) ||
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>'            || chr(10) ||
                        '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>'           || chr(10) ||
                        '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>'             || chr(10) ||
                       '</Borders>'                                                                       || chr(10) ||
                       '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="9" ss:Color="#000000"'        || chr(10) ||
                        'ss:Bold="1"/>'                                                                   || chr(10) ||
                       '<Interior ss:Color="#C5D9F1" ss:Pattern="Solid"/>'                                || chr(10) ||
                      '</Style>'                                                                          || chr(10) ||
                      '<Style ss:ID="s96">'                                                               || chr(10) ||
                       '<Alignment ss:Horizontal="Center" ss:Vertical="Top" ss:WrapText="1"/>'            || chr(10) ||
                       '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="12" ss:Color="#000000"'       || chr(10) ||
                        'ss:Bold="1"/>'                                                                   || chr(10) ||    
                      '</Style>'                                                                          || chr(10) ||
                      '<Style ss:ID="s97">'                                                               || chr(10) ||
                       '<Alignment ss:Horizontal="Left" ss:Vertical="Top" ss:WrapText="1"/>'              || chr(10) ||
                       '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="9" ss:Color="#000000"/>'      || chr(10) ||
                      '</Style>'                                                                          || chr(10) ||
                      
                        '<Style ss:ID="s77" ss:Parent="s16">'                                             || chr(10) ||      
                        '<Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>'        || chr(10) ||
                        '<Borders>'                                                                       || chr(10) ||
                         '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>'         || chr(10) ||
                         '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>'           || chr(10) ||
                         '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>'          || chr(10) ||
                         '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>'            || chr(10) ||
                        '</Borders>'                                                                      || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="9" ss:Color="#000000"'       || chr(10) ||
                         'ss:Bold="1"/>'                                                                  || chr(10) ||
                        '<Interior ss:Color="#C5D9F1" ss:Pattern="Solid"/>'                               || chr(10) ||
                        '<NumberFormat ss:Format="_(* #,##0_);_(* \(#,##0\);_(* &quot;-&quot;??_);_(@_)"/>'|| chr(10) ||
                       ' </Style>'                                                                        || chr(10) || 
                       '<Style ss:ID="s82">'                                                              || chr(10) ||   
                        '<Borders>'                                                                       || chr(10) ||
                         '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>'         || chr(10) ||
                         '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>'           || chr(10) ||
                         '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>'          || chr(10) ||
                         '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>'            || chr(10) ||
                        '</Borders>'                                                                      || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="9" ss:Color="#000000"/>'     || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||
                       '<Style ss:ID="s83" ss:Parent="s16">'                                              || chr(10) ||
                        '<Borders>'                                                                       || chr(10) ||
                         '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>'         || chr(10) ||
                         '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>'           || chr(10) ||
                         '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>'          || chr(10) ||
                         '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>'            || chr(10) ||
                        '</Borders>'                                                                      || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="9" ss:Color="#000000"/>'     || chr(10) ||
                        '<Interior/>'                                                                     || chr(10) ||
                        '<NumberFormat ss:Format="_(* #,##0.00_);_(* \(#,##0.00\);_(* &quot;-&quot;??_);_(@_)"/>'|| chr(10) ||
                       '</Style>'                                                                         || chr(10) ||          
                       '<Style ss:ID="s84">'                                                              || chr(10) ||
                        '<Borders>'                                                                       || chr(10) ||
                         '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>'         || chr(10) ||
                         '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>'           || chr(10) ||
                         '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>'          || chr(10) ||
                         '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>'            || chr(10) ||
                        '</Borders>'                                                                      || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="9" ss:Color="#000000"/>'     || chr(10) ||

                       '</Style>'                                                                         || chr(10) ||
                       '<Style ss:ID="s85">'                                                              || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="8" ss:Color="#000000"/>'     || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||
                       '<Style ss:ID="s78">'                                                              || chr(10) ||
                        '<Borders>'                                                                       || chr(10) ||
                         '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>'         || chr(10) ||
                         '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>'           || chr(10) ||
                         '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>'          || chr(10) ||
                         '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>'            || chr(10) ||
                        '</Borders>'                                                                      || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="9" ss:Color="#000000"'       || chr(10) ||
                         'ss:Bold="1"/>'                                                                  || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||   
                       '<Style ss:ID="s79">'                                                              || chr(10) ||
                        '<Borders>'                                                                       || chr(10) ||
                         '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>'         || chr(10) ||
                         '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>'           || chr(10) ||
                         '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>'          || chr(10) ||
                         '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>'            || chr(10) ||
                        '</Borders>'                                                                      || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="8" ss:Color="#000000"/>'     || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||
                       '<Style ss:ID="s80" ss:Parent="s16">'                                              || chr(10) ||
                        '<Borders>'                                                                       || chr(10) ||   
                         '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>'         || chr(10) ||
                         '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>'           || chr(10) ||
                         '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>'          || chr(10) ||
                         '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>'            || chr(10) ||
                        '</Borders>'                                                                      || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="8" ss:Color="#000000"/>'     || chr(10) ||
                        '<Interior/>'                                                                     || chr(10) ||
                        '<NumberFormat ss:Format="_(* #,##0.00_);_(* \(#,##0.00\);_(* &quot;-&quot;??_);_(@_)"/>'|| chr(10) ||
                       '</Style>'                                                                         || chr(10) ||          
                       '<Style ss:ID="s81">'                                                              || chr(10) ||
                        '<Borders>'                                                                       || chr(10) ||
                         '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>'         || chr(10) ||
                         '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>'           || chr(10) ||
                         '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>'          || chr(10) ||
                         '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>'            || chr(10) ||
                        '</Borders>'                                                                      || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="8" ss:Color="#000000"/>'     || chr(10) ||
                        '<NumberFormat ss:Format="dd/mm/yyyy;@"/>'                                        || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||
                       
                       
                       '<Style ss:ID="s89">'                                                              || chr(10) ||
                        '<Borders/>'                                                                      || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Color="#000000" ss:Bold="1"/>'     || chr(10) ||
                        '<Interior/>'                                                                     || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||
                       '<Style ss:ID="s91">'                                                              || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="9"/>'                        || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||
                       '<Style ss:ID="s92">'                                                              || chr(10) ||
                        '<Font ss:FontName="Arial" x:Family="Swiss"/>'                                    || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||   
                       '<Style ss:ID="s93">'                                                              || chr(10) ||
                        '<Font ss:FontName="Calibri" x:Family="Swiss" ss:Size="11" ss:Color="#FF0000"/>'  || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||
                       '<Style ss:ID="s94">'                                                              || chr(10) ||   
                        '<Font ss:FontName="Arial" x:Family="Swiss" ss:Size="9" ss:Color="#000000"/>'     || chr(10) ||
                       '</Style>'                                                                         || chr(10) ||
                                                                                                          
                        '</Styles>';       


   END lp_abr_archivo;

   /* Cierra el documento XML formato Excel. */
   PROCEDURE lp_cie_archivo
   (
      v_xml_body IN OUT NOCOPY CLOB
   )IS
   BEGIN
      v_xml_body := v_xml_body || '</Workbook>';
   END lp_cie_archivo;




   /* Crea la nueva hoja a escribir */
   PROCEDURE lp_abr_hoja
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_NOM_HOJA VARCHAR2
   )IS
   BEGIN
      v_xml_body := v_xml_body || '<Worksheet ss:Name="' || V_NOM_HOJA ||
                        '"><Table>';
   END lp_abr_hoja;


   /* Cierra el documento XML formato Excel. */
   PROCEDURE lp_cie_hoja
   (
      v_xml_body IN OUT NOCOPY CLOB
   )IS
   BEGIN
      v_xml_body := v_xml_body || '</Table></Worksheet>';
   END lp_cie_hoja;


    /* Define las columnas del archivo */
   PROCEDURE lp_def_columnas
   (
      v_xml_body IN OUT NOCOPY CLOB
   )IS
   BEGIN
      v_xml_body := v_xml_body || '<Column ss:StyleID="s62" ss:AutoFitWidth="0" ss:Width="20.25"/>'|| chr(10) ||
   '<Column ss:StyleID="s62" ss:AutoFitWidth="0" ss:Width="24.75"/>'|| chr(10) ||   
   '<Column ss:StyleID="s62" ss:AutoFitWidth="0" ss:Width="222.75"/>'|| chr(10) ||
   '<Column ss:StyleID="s62" ss:AutoFitWidth="0" ss:Width="49.5"/>'|| chr(10) ||
   '<Column ss:StyleID="s62" ss:Width="70.5"/>'|| chr(10) ||
   '<Column ss:StyleID="s62" ss:AutoFitWidth="0" ss:Width="96"/>'|| chr(10) ||
   '<Column ss:StyleID="s62" ss:AutoFitWidth="0" ss:Width="57.75"/>'|| chr(10) ||
   '<Column ss:StyleID="s62" ss:AutoFitWidth="0" ss:Width="62.25"/>'|| chr(10) ||
   '<Column ss:StyleID="s62" ss:Width="53.25"/>'; 

   END lp_def_columnas;


   /* Crea la cabecera del informe  LOGO*/
   PROCEDURE lp_gen_cab_logo

   (
      v_xml_body IN OUT NOCOPY CLOB
   )IS
   BEGIN
   v_xml_body := v_xml_body || '<Row ss:AutoFitHeight="0">
   
    <Cell ss:Index="2" ss:MergeAcross="1" ss:MergeDown="9" ss:StyleID="s63"><Data
      ss:Type="String">&#10;LOGO  GNB&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;-|&#10;&#10;LOGO  GNB&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;-|&#10;&#10;LOGO  GNB&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;-|&#10;&#10;LOGO  GNB&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;-|&#10;&#10;LOGO  GNB&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;&#45;-|</Data></Cell>
   </Row>
   <Row ss:AutoFitHeight="0" ss:Span="4"/>'; 
   END lp_gen_cab_logo;

   /* Crea la cabecera del informe FECHA */
   PROCEDURE lp_gen_cab_fecha

   (
      v_xml_body IN OUT NOCOPY CLOB,
      v_fecha varchar2
   )IS
   BEGIN
   v_xml_body := v_xml_body || '<Row ss:Index="8" ss:AutoFitHeight="0">
    <Cell ss:Index="5" ss:MergeAcross="4" ss:StyleID="s65"><Data ss:Type="String"> '||
    v_fecha||' </Data></Cell>'|| chr(10) ||
   '</Row>'; 
   END lp_gen_cab_fecha;

   /* saltos de fila*/
   PROCEDURE lp_ins_filas
   (
      v_xml_body IN OUT NOCOPY CLOB
   )IS
   BEGIN
      v_xml_body := v_xml_body || '<Row> </Row>'; 

   END lp_ins_filas;

   /* saltos de fila tabla*/
   PROCEDURE lp_ins_filas_tab
   (
      v_xml_body IN OUT NOCOPY CLOB
   )IS
   BEGIN
      v_xml_body := v_xml_body || '<Row ss:AutoFitHeight="0">
    <Cell ss:Index="3" ss:StyleID="s82"></Cell>
    <Cell ss:StyleID="s82"></Cell>
    <Cell ss:StyleID="s82"></Cell>
    <Cell ss:StyleID="s83"></Cell>
    <Cell ss:StyleID="s83"></Cell>
    <Cell ss:StyleID="s84"></Cell>
    <Cell ss:StyleID="s84"></Cell>
    <Cell ss:StyleID="s85"/>
   </Row>'; 

   END lp_ins_filas_tab;



   /* inserta destinatario*/
   PROCEDURE lp_ins_destinatario
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_NOM_AUDITOR VARCHAR2,
      V_DIR_AUDITOR VARCHAR2,
      V_TEL_AUDITOR VARCHAR2
   )IS
   v_direccion_auditor varchar2(2000);
   BEGIN

   --recuperamos la dirección del auditor (AUDITOR)
   if P_COD_DIR_AUDITOR != 'ingresar dirección Auditor' then
     begin
        select  D.DIRECCION
        into v_direccion_auditor
        from BA_DIRECCIONES D
        where d.cod_persona = P_COD_AUDITOR
        and   d.cod_direccion = P_COD_DIR_AUDITOR;
     exception
        when no_Data_found then
           v_nom_empresa := 'Cod empresa (auditor): '||P_COD_CLIENTE||'no existe';
        when others then
           raise_application_error(-40000,'Error al buscar el nombre del auditor: '||sqlerrm);
     end;
   else 
     v_direccion_auditor := P_COD_DIR_AUDITOR;
   end if;


      v_xml_body := v_xml_body || '<Row ss:AutoFitHeight="0">'|| chr(10) || 
    '<Cell ss:Index="3" ss:StyleID="s68"><Data ss:Type="String">Señores</Data></Cell>'|| chr(10) || 
   '</Row>'|| chr(10) || 
   '<Row ss:AutoFitHeight="0">'|| chr(10) || 
    '<Cell ss:Index="3" ss:StyleID="s68"><Data ss:Type="String"> '||
    V_NOM_AUDITOR||' </Data></Cell>'|| chr(10) || 
   '</Row>'|| chr(10) || 
   '<Row ss:AutoFitHeight="0" ss:Height="28.5">'|| chr(10) || 
    '<Cell ss:Index="3" ss:StyleID="s68"><Data ss:Type="String"> '||
    v_direccion_auditor||' </Data></Cell>'|| chr(10) || 
   '</Row>'|| chr(10) || 
   '<Row ss:AutoFitHeight="0">'|| chr(10) || 
    '<Cell ss:Index="3" ss:StyleID="s68"><Data ss:Type="String"> '||
    V_TEL_AUDITOR||' </Data></Cell>'|| chr(10) || 
   '</Row>'|| chr(10) || 
   '<Row ss:AutoFitHeight="0">'|| chr(10) || 
    '<Cell ss:Index="3" ss:StyleID="s68"><Data ss:Type="String"> '||
    P_MAIL_AUDITOR||' </Data></Cell>'|| chr(10) || 
   '</Row>'|| chr(10) ||
   '<Row ss:AutoFitHeight="0">'|| chr(10) || 
    '<Cell ss:Index="3" ss:StyleID="s68"><Data ss:Type="String">Asunción</Data></Cell>'|| chr(10) || 
   '</Row>'|| chr(10) || 
   '<Row ss:AutoFitHeight="0" ss:Height="15">'|| chr(10) || 
    '<Cell ss:Index="3" ss:StyleID="s69"><Data ss:Type="String">Presente</Data></Cell>'|| chr(10) || 
    '<Cell ss:Index="7" ss:StyleID="s70"></Cell>'|| chr(10) || 
   '</Row>'; 
   END lp_ins_destinatario;


   /* inserta referencia*/
   PROCEDURE lp_ins_referencia
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_NOM_EMPRESA VARCHAR2
   )IS
   BEGIN
      v_xml_body := v_xml_body || '<Row ss:AutoFitHeight="0" ss:Height="15">'|| chr(10) || 
    '<Cell ss:Index="5" ss:StyleID="s70"><Data ss:Type="String"> '||
     V_NOM_EMPRESA||' </Data>'|| chr(10) || 
      '</Cell>'|| chr(10) || 
   '</Row>'; 
   END lp_ins_referencia;

   /* inserta inicio de informe*/
   PROCEDURE lp_ins_ini_informe
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_NOM_EMPRESA VARCHAR2,
      V_FEC_SALDO VARCHAR2
   )IS
   BEGIN
      v_xml_body := v_xml_body || '<Row ss:AutoFitHeight="0" ss:Height="15">'|| chr(10) || 
    '<Cell ss:Index="3" ss:StyleID="s72"><Data ss:Type="String">De nuestra consideración:</Data></Cell>'|| chr(10) || 
   '</Row>'|| chr(10) || 
  ' <Row ss:AutoFitHeight="0" ss:Height="13.5">'|| chr(10) || 
   '</Row>'|| chr(10) || 
   '<Row ss:AutoFitHeight="0">'|| chr(10) || 
    '<Cell ss:Index="3" ss:MergeAcross="6" ss:MergeDown="1" ss:StyleID="s74"><Data'|| chr(10) || 
      'ss:Type="String">       En conformidad a lo solicitado expresamente por '||
     V_NOM_EMPRESA||', se cumple en informarles la posición de los saldos de cuentas a su nombre y titularidad, al '||
     V_FEC_SALDO||', para los siguientes rubros:</Data></Cell>'|| chr(10) || 
   '</Row>'; 
   END lp_ins_ini_informe;


   /* inserta DETALLE de informe*/
   PROCEDURE lp_ins_det_informe
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_FEC_SALDO VARCHAR2
   )IS
   BEGIN
      /*CABECERA DE TABLA DE CUENTAS*/
      v_xml_body := v_xml_body || '   <Row ss:Index="28" ss:AutoFitHeight="0" ss:Height="24">
    <Cell ss:Index="3" ss:StyleID="s75"><Data ss:Type="String">DESCRIPCIÓN</Data></Cell>
    <Cell ss:StyleID="s75"><Data ss:Type="String">MONEDA</Data><NamedCell
      ss:Name="Print_Area"/></Cell>
    <Cell ss:StyleID="s75"><Data ss:Type="String">NRO. DE CUENTA</Data><NamedCell
      ss:Name="Print_Area"/></Cell>
    <Cell ss:StyleID="s77"><Data ss:Type="String">SALDOS AL '||V_FEC_SALDO||'</Data><NamedCell
      ss:Name="Print_Area"/></Cell>
    <Cell ss:StyleID="s77"><Data ss:Type="String">TASA INT. (%)</Data><NamedCell
      ss:Name="Print_Area"/></Cell>
    <Cell ss:StyleID="s75"><Data ss:Type="String">FECHA APERTURA</Data><NamedCell
      ss:Name="Print_Area"/></Cell>
    <Cell ss:StyleID="s75"><Data ss:Type="String">FECHA VTO.</Data><NamedCell
      ss:Name="Print_Area"/></Cell>
   </Row>'; 





   --crear cursor de cuentas
   /*LOOP ARMADO DE TABLA DE CUENTAS*/

   INSERT INTO GE_POS_CON_CLIENTE ( OBSERVACION)
                                     VALUES
                                     (P_FECHA||'  **SEG'); 
   COMMIT;    
   v_aux := 0;--inicia con 0
   for c in c_cuentas loop
      if v_aux != c.Orden then
         v_aux := c.Orden;--guardamos el orden actual
         --se inserta fila dentro de la tabla
         if v_aux > 1 then
            lp_ins_filas_tab(v_xml_body);
         end if;
         --título de cuenta
         lp_ins_tipo_cuenta(v_xml_body,c.des_tipo);
         
      end if;
      --detalle de cuenta
      lp_ins_det_cuenta(v_xml_body,c.descripcion,
                                   c.cod_moneda,
                                   c.nro_cuenta,
                                   c.saldo,
                                   c.tas_nominal,
                                   to_char(c.fec_apertura,'dd/mm/rrrr'),
                                   to_char(c.fec_vencimiento,'dd/mm/rrrr'));

     INSERT INTO GE_POS_CON_CLIENTE (FEC_GENERACION,
                                     COD_PERSONA,
                                     NRO_CUENTA,
                                     COD_TASA,
                                     VAL_TASA,
                                     COD_MONEDA,
                                     FEC_APERTURA,
                                     FEC_VENCIMIENTO,
                                     SALDO,
                                     OBSERVACION)
                                     VALUES
                                     (sysdate,
                                     P_COD_CLIENTE,
                                     C.NRO_CUENTA,
                                     0,
                                     C.TAS_NOMINAL,
                                     C.COD_MONEDA,
                                     C.FEC_APERTURA,
                                     C.FEC_VENCIMIENTO,
                                     C.SALDO,
                                     P_OBSERVACION);                              
   /* FIN LOOP ARMADO DE TABLA DE CUENTAS*/
   end loop;


   
   lp_ins_filas(v_xml_body);

   --firmantes DE LAS CUENTAS
   lp_ins_fir_cuenta(v_xml_body);

                                                              


   
   END lp_ins_det_informe;


   /* inserta título tipo cuenta en el detalle*/
   PROCEDURE lp_ins_tipo_cuenta
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_DES_TIP_CTA VARCHAR2
   )IS
   BEGIN

   v_xml_body := v_xml_body || '<Row ss:AutoFitHeight="0">
    <Cell ss:Index="3" ss:StyleID="s78"><Data ss:Type="String">'||V_DES_TIP_CTA||'</Data></Cell>
    <Cell ss:StyleID="s79"></Cell>
    <Cell ss:StyleID="s79"></Cell>
    <Cell ss:StyleID="s80"></Cell>
    <Cell ss:StyleID="s80"></Cell>
    <Cell ss:StyleID="s81"></Cell>
    <Cell ss:StyleID="s81"></Cell>
   </Row>'; 

   END lp_ins_tipo_cuenta;   


   /* inserta título tipo cuenta en el detalle*/
   PROCEDURE lp_ins_det_cuenta
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_DES_CTA VARCHAR2,
      V_DES_MONEDA VARCHAR2,
      V_NRO_CUENTA VARCHAR2,
      V_SALDO  NUMBER,
      V_TASA NUMBER,
      V_FEC_APERTURA VARCHAR2,
      V_FEC_VENCIMIENTO VARCHAR2
   )IS
   BEGIN
     v_xml_body := v_xml_body || '<Row ss:AutoFitHeight="0">
      <Cell ss:Index="3" ss:StyleID="s82"><Data ss:Type="String">'||V_DES_CTA||'</Data></Cell>
      <Cell ss:StyleID="s82"><Data ss:Type="String">'||V_DES_MONEDA||'</Data></Cell>
      <Cell ss:StyleID="s82"><Data ss:Type="String">'||V_NRO_CUENTA||'</Data></Cell>
      <Cell ss:StyleID="s83"><Data ss:Type="Number">'||V_SALDO||'</Data></Cell>
      <Cell ss:StyleID="s83"><Data ss:Type="Number">'||V_TASA||'</Data></Cell>
      <Cell ss:StyleID="s84"><Data ss:Type="String">'||V_FEC_APERTURA||'</Data></Cell>
      <Cell ss:StyleID="s84"><Data ss:Type="String">'||V_FEC_VENCIMIENTO||'</Data></Cell>  
     </Row>'; 

     /*********************ESCRIBIMOS EN BASES DE DATOS EL DETALLE Y FINAL DEL INFORME***************************/
     --realiza la escritura en directorio de base de datos (AGREGA EL DETALLE Y EL FINAL
     lp_cre_xml_add(p_filename => 'Informe_Posición_Cliente_'||P_COD_CLIENTE,
                                       p_dir      => g_repository,
                                       p_clob     => v_xml_body);
     /*********************ESCRIBIMOS EN BASES DE DATOS EL DETALLE Y FINAL DEL INFORME***************************/
     v_xml_body := null;

   END lp_ins_det_cuenta;     


   /* inserta firmantes de cuentas*/
   PROCEDURE lp_ins_fir_cuenta
   (
      v_xml_body IN OUT NOCOPY CLOB
   )IS
   BEGIN
   /*título de firmantes*/
   v_xml_body := v_xml_body || '<Row ss:AutoFitHeight="0" ss:Height="15">
    <Cell ss:Index="3" ss:StyleID="s89"><Data ss:Type="String">FIRMANTES </Data></Cell>
   </Row> 
   <Row></Row>'; 

   
   /*LOOP DE INSERCIÓN DE FIRMANTE*/
   for c in c_firmantes loop
     lp_ins_firmante(v_xml_body,c.nom_completo,c.des_relacion);
   end loop;



   --se inserta dos filas
   lp_ins_filas(v_xml_body);
   lp_ins_filas(v_xml_body);

   END lp_ins_fir_cuenta;

   /* inserta firmantes de cuentas*/
   PROCEDURE lp_ins_firmante
   (
      v_xml_body IN OUT NOCOPY CLOB,
      V_NOMBRE VARCHAR2,
      V_CARGO VARCHAR2 
   )IS
   BEGIN
   v_xml_body := v_xml_body || '<Row ss:AutoFitHeight="0" ss:Height="15">
    <Cell ss:Index="3" ss:StyleID="s91"><Data ss:Type="String">'||V_NOMBRE||'</Data></Cell>
    <Cell ss:StyleID="s92"><Data ss:Type="String">'||V_CARGO||'</Data></Cell>
   </Row>'; 

   

   END lp_ins_firmante;



   /* inserta fin de informe*/
   PROCEDURE lp_ins_fin_informe
   (
      v_xml_body IN OUT NOCOPY CLOB
   )IS
    
   BEGIN
      v_xml_body := v_xml_body || '<Row ss:AutoFitHeight="0" ss:Height="55.5">
    <Cell ss:Index="3" ss:MergeAcross="6" ss:StyleID="s74"><Data ss:Type="String">             La presente no implica responsabilidad o garantía alguna de nuestra parte, siendo la misma otorgada a razón de la solicitud formal realizada por el Cliente referido, y las informaciones contenidas son transmitidas con la obligación de conservar el secreto bancario, conforme a las disposiciones de la Ley 861/96 General de Bancos y otras Entidades Financieras.&#10;&#10;&#10;         </Data></Cell>
   </Row>
   <Row></Row>
   <Row>
    <Cell ss:Index="3" ss:MergeAcross="6" ss:StyleID="s63"><Data ss:Type="String">             Sin otro particular, hacemos propicia la oportunidad para saludarles muy atentamente.</Data></Cell>
   </Row>
   <Row></Row>
   <Row></Row>
   <Row></Row>
   <Row></Row>
   <Row ss:AutoFitHeight="0" ss:Height="15.75">
    <Cell ss:Index="3" ss:MergeAcross="6" ss:StyleID="s96"><Data ss:Type="String"> '||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</Data></Cell>
   </Row>
   <Row></Row>
   <Row></Row>
   <Row></Row>
   <Row></Row>   
   <Row ss:AutoFitHeight="0">
    <Cell ss:Index="3" ss:StyleID="s97"><Data ss:Type="String">ITGF</Data></Cell>
   </Row>';
   END lp_ins_fin_informe;


/*Escribe el archivo XML*/   
   PROCEDURE lp_cre_xml
     (
          p_filename IN VARCHAR2,
          p_dir      IN VARCHAR2,
          p_clob     IN CLOB
     ) IS

          c_amount CONSTANT BINARY_INTEGER := 32767;
          l_buffer   VARCHAR2(32767);
          l_chr10    PLS_INTEGER;
          l_cloblen  PLS_INTEGER;
          l_fhandler utl_file.file_type;
          l_pos      PLS_INTEGER := 1;

     BEGIN

          l_cloblen  := dbms_lob.getlength(p_clob);
          l_fhandler := utl_file.fopen(p_dir, p_filename, 'W', c_amount);

          WHILE l_pos < l_cloblen
          LOOP
               l_buffer := dbms_lob.substr(p_clob, c_amount, l_pos);
               EXIT WHEN l_buffer IS NULL;
               l_chr10 := instr(l_buffer, chr(10), -1);
               IF l_chr10 != 0
               THEN
                    l_buffer := substr(l_buffer, 1, l_chr10 - 1);
               END IF;
               utl_file.put_line(l_fhandler, l_buffer, TRUE);
               l_pos := l_pos + least(length(l_buffer) + 1, c_amount);
          END LOOP;

          utl_file.fclose(l_fhandler);

     EXCEPTION
          --WE SHOULD HANDLE THE FILE EXCEPTIONS HERE!!!!!
          WHEN OTHERS THEN
               IF utl_file.is_open(l_fhandler)
               THEN
                    utl_file.fclose(l_fhandler);
               END IF;
               RAISE;
     END lp_cre_xml;

   


/*Escribe el archivo XML*/   
   PROCEDURE lp_cre_xml_add
     (
          p_filename IN VARCHAR2,
          p_dir      IN VARCHAR2,
          p_clob     IN CLOB
     ) IS

          c_amount CONSTANT BINARY_INTEGER := 32767;
          l_buffer   VARCHAR2(32767);
          l_chr10    PLS_INTEGER;
          l_cloblen  PLS_INTEGER;
          l_fhandler utl_file.file_type;
          l_pos      PLS_INTEGER := 1;

     BEGIN

          l_cloblen  := dbms_lob.getlength(p_clob);
          l_fhandler := utl_file.fopen(p_dir, p_filename, 'a', c_amount);

          WHILE l_pos < l_cloblen
          LOOP
               l_buffer := dbms_lob.substr(p_clob, c_amount, l_pos);
               EXIT WHEN l_buffer IS NULL;
               l_chr10 := instr(l_buffer, chr(10), -1);
               IF l_chr10 != 0
               THEN
                    l_buffer := substr(l_buffer, 1, l_chr10 - 1);
               END IF;
               utl_file.put_line(l_fhandler, l_buffer, TRUE);
               l_pos := l_pos + least(length(l_buffer) + 1, c_amount);
          END LOOP;

          utl_file.fclose(l_fhandler);

     EXCEPTION
          --WE SHOULD HANDLE THE FILE EXCEPTIONS HERE!!!!!
          WHEN OTHERS THEN
               IF utl_file.is_open(l_fhandler)
               THEN
                    utl_file.fclose(l_fhandler);
               END IF;
               RAISE;
     END lp_cre_xml_add;









/* PROCESO PRINCIPAL DEL PROCEDIMIENTO */

BEGIN
   pre_cam_for_numerico('.,');--Sergio Servín DYDMR-2128, 16/07/2015 
   --recuperamos los datos para el informe (CLIENTE)
   begin
      select p.nom_completo
      into v_nom_empresa
      from ba_personas p
      where p.cod_persona = P_COD_CLIENTE;
   exception
      when no_Data_found then
         v_nom_empresa := 'Cod empresa: '||P_COD_CLIENTE||'no existe';
      when others then
         raise_application_error(-40000,'Error al buscar el nombre del cliente: '||sqlerrm);
   end;


   --Prepara/crea el archivo  
   lp_abr_archivo(myexcelcontent);

   --crea la hoja a escribir
   lp_abr_hoja(myexcelcontent,'INFORME');

   --define las columnas
   lp_def_columnas(myexcelcontent);

   --define el área del logo del BBVA
   lp_gen_cab_logo(myexcelcontent);

   --inserta la fecha del documento
   Select 'Asunción '|| to_char(sysdate,'DD')||' de '||trim(to_char(sysdate,'month'))||' del '||to_char(sysdate,'rrrr') 
   into v_Fecha
   from dual;
   lp_gen_cab_fecha(myexcelcontent,v_Fecha);
   --se agrega 4 filas vacías
   lp_ins_filas(myexcelcontent);
   lp_ins_filas(myexcelcontent);
   lp_ins_filas(myexcelcontent);
   lp_ins_filas(myexcelcontent);

   --se inserta el destinatario
   lp_ins_destinatario(myexcelcontent,
                       P_NOM_AUDITOR,--nombre auditor
                       P_COD_DIR_AUDITOR,--dirección auditor
                       P_TEL_AUDITOR);--tel auditor
   --se inserta 2 filas vacías                    
   lp_ins_filas(myexcelcontent);
   lp_ins_filas(myexcelcontent);   
   --se inserta la referencia
   lp_ins_referencia(myexcelcontent,
                    'Referencia: '||v_nom_empresa);
   --se inserta 1 fila vacía                  
   lp_ins_filas(myexcelcontent); 
   --SE inserta inicio de informe
   lp_ins_ini_informe(myexcelcontent,
                     v_nom_empresa,
                     p_fecha);
   --se inserta 1 fila vacía                  
   lp_ins_filas(myexcelcontent);  


   /*********************ESCRIBIMOS EN BASES DE DATOS EL INICIO DEL INFORME***************************/
   --realiza la escritura en directorio de base de datos
   lp_cre_xml(p_filename => 'Informe_Posición_Cliente_'||P_COD_CLIENTE,
                                     p_dir      => g_repository,
                                     p_clob     => myexcelcontent);
   /*********************ESCRIBIMOS EN BASES DE DATOS EL INICIO DEL INFORME***************************/
   --reiniciamos la variable para evitar sobrecarca del clob
   myexcelcontent := null;                                  
   



   --detalle del informe
   lp_ins_det_informe(myexcelcontent,
                      p_fecha);  
                     

            
  --fin de informe
  lp_ins_fin_informe(myexcelcontent);




   --cierra hoja excel
   lp_cie_hoja(myexcelcontent);

   --cierra el archivo excel
   lp_cie_archivo(myexcelcontent);


     /*********************ESCRIBIMOS EN BASES DE DATOS EL DETALLE Y FINAL DEL INFORME***************************/
     --realiza la escritura en directorio de base de datos (AGREGA EL DETALLE Y EL FINAL
     lp_cre_xml_add(p_filename => 'Informe_Posición_Cliente_'||P_COD_CLIENTE,
                                       p_dir      => g_repository,
                                       p_clob     => myexcelcontent);
     /*********************ESCRIBIMOS EN BASES DE DATOS EL DETALLE Y FINAL DEL INFORME***************************/
   /*FIN ESCRITURA DE ARCHIVO XML (FORMATO EXCEL)*/
   
   
    --copiamos el archivo generado al directorio ramail
    v_respuesta := pa_file_ftp.fu_put_ascii(g_ip, g_port, g_user,
                                          g_pass, g_repository,
                                          'Informe_Posición_Cliente_'||P_COD_CLIENTE, g_extractos||'Informe_Posición_Cliente_'||P_COD_CLIENTE||'.XML');

IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
   dbms_output.put_line('OK!!');
   P_RESPUESTA := 'Archivo "Informe_Posición_Cliente_'||P_COD_CLIENTE||'" creado exitosamente en la dirección \\192.168.254.136\ramail\extractos';
else
   dbms_output.put_line(sqlerrm);
   P_RESPUESTA := 'Error al generar archivo: '||v_respuesta||' - '||sqlerrm;
end if;
commit;
END;
/

