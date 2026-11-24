CREATE OR REPLACE FUNCTION IT.FUL_OBT_MSJ_SWIFT(p_nro_operacion in number)
  RETURN VARCHAR2 IS
  v_nom_archivo varchar2(100) := null;
  v_texto varchar2(3000) := null;
  cursor c_transf is
      select * from lc_transferencias
       where nro_operacion = p_nro_operacion;
  ct c_transf%rowtype;
  v_cod_swift            varchar2(20);
  v_salto                varchar2(2) := CHR(13)||CHR(10);
  v_nro_cta_corresponsal varchar2(50);
  v_cod_swi_corresponsal varchar2(12);
  v_nom_bco_cor_contra   varchar2(100);
  v_cod_swi_cor_contra   varchar2(50);
  v_cod_per_cor_contra   varchar2(20);
  v_cod_pai_cor_contra   number(5);
  v_des_pai_cor_contra   varchar2(100);
  v_cod_ciu_cor_contra   number(5);
  v_des_ciu_cor_contra   varchar2(100);
  v_det_cargo            varchar2(1):='N';
  v_uuid                 varchar2(100);
  v_tex_comentario       varchar2(2000);
  v_aux_caracteres       number :=0;
  v_linea                number :=0;
  v_posicion             number :=0;
  
  function fug_eli_caracteres(p_cadena VARCHAR2) RETURN VARCHAR2 IS
      v_cadena VARCHAR2(4000);
  Begin
    IF p_cadena IS NOT NULL THEN
      v_cadena := translate(p_cadena,
                            'áéíóúàèìòùäëïöüÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ´~_|°ºª¬!"&¿*¨{}^`¿[];><Çç',
                            'aeiouaeiouaeiouAEIOUYAEIOUAEIOU. --ooa ..y?x.()  ?():)(Nn');
      v_cadena := translate(v_cadena,
                            'âêîñôûÂÊÎÑÔÛÃãÐÕ×ØÝÞßåæðõø÷ýþÿAa\@¢£¤¥¦§©«®¯±²³µ¶·¸¹º»¼½¾',
                            'aeinouAEINOUAaDO     a  o  y yAa/                        ');
      v_cadena := translate(v_cadena, '''', '  ');
      v_cadena := REPLACE(v_cadena,'%','PT');
      v_cadena := REPLACE(v_cadena,'#','Nr');
      v_cadena := REPLACE(v_cadena,'@','at');
    END IF;
    RETURN(v_cadena);

  end fug_eli_caracteres;
  
BEGIN
  pre_cam_for_numerico('.,');
  -- defino el nombre del archivo
  v_nom_archivo := 'PYCOR'||p_nro_operacion||'.ICR';
  -- leo los datos del registro de la operacion
  open c_transf;
  fetch c_transf into ct;
  close c_transf;
  -- obtengo los datos del banco corresponsal
  begin
      select upper(substr(b.cod_swift,1,8)||'X'||substr(b.cod_swift,9)), a.nro_cuenta
        into v_cod_swi_corresponsal, v_nro_cta_corresponsal
        from ge_bancos b, cc_cta_bancarias a
       where a.cod_moneda = ct.cod_moneda
         and a.estado = 'N'
         and a.cod_modalidad = 45
         and a.cod_banco = ct.cod_bco_corresponsal
         and b.cod_banco = a.cod_banco;
  exception
      when no_data_found then
        raise_application_error(-20009,'Corresponsal inexistente');
      when too_many_rows then
        raise_application_error(-20010,'Varios Correponsales definidos');
      when others then
        raise_application_error(-20011,'Recup.Corresp.'|| sqlerrm);
  end;
  -- obtengo los datos del banco corresponsal del operante
  begin
     select a.descripcion, upper(a.cod_swift), a.cod_persona
       into v_nom_bco_cor_contra, v_cod_swi_cor_contra, v_cod_per_cor_contra
       from ge_bancos a
      where a.cod_banco = ct.cod_bco_cor_contra;
  exception
     when others then
         v_nom_bco_cor_contra := null;
         v_cod_swi_cor_contra := null;
  end;
  --wa:16/01/2015 Si es Hbank tiene otra lógica
  if ct.usu_insercion <> 'HBANK' then
    pre_obt_ciu_pais(v_cod_per_cor_contra, v_cod_pai_cor_contra, v_des_pai_cor_contra, v_cod_ciu_cor_contra, v_des_ciu_cor_contra);
  elsif  ct.usu_insercion = 'HBANK' then
    v_nom_bco_cor_contra:= ct.nom_bco_cor_contra;
    v_cod_swi_cor_contra:=ct.cod_swi_bco_contra;
    v_cod_pai_cor_contra:=ct.cod_pai_bco_contra;
    v_cod_ciu_cor_contra:=ct.cod_ciu_bco_contra;
       --Obtenemos Desc. de Pais
        begin
          select a.descripcion
             into v_des_pai_cor_contra
              from ba_paises a
               where a.cod_pais=ct.cod_pai_bco_contra;
        exception
          when no_data_found then
            v_des_pai_cor_contra:=NULL;
          when others then
            v_des_pai_cor_contra:=NULL;
        end;
        --Obtenemos Desc. de Ciudad
        begin
          select a.descripcion
             into v_des_ciu_cor_contra
              from ba_ciudades a
               where a.cod_ciudad=ct.cod_ciu_bco_contra;
        exception
          when no_data_found then
            v_des_ciu_cor_contra:=NULL;
          when others then
            v_des_ciu_cor_contra:=NULL;
        end;
  end if;
 -- obtengo el codigo de swift del banco origen
  select cod_swift into v_cod_swift from ge_bancos where cod_banco = fug_obt_cod_banco;
  -- armo las partes del cuerpo del mensaje
  -- ********************************** cabecera ****************************************************
  v_texto :=          '{1:F01'||v_cod_swift||'XXX0000000000}';
  v_texto := v_texto||'{2:I'||ct.cod_msj_swift||rpad(upper(v_cod_swi_corresponsal),12,'X')||'N'||'}';
  --GPII Identificamos si es GPII
  if nvl(ct.gpi,'N')='S' then
    --Agregamos campos propios de GPII en Cabecera
    v_uuid:= null;
    v_uuid:= fug_obt_cod_uuid();
    v_texto := v_texto||'{3:{111:001}{121:'||v_uuid||'}}';
  end if;
  v_texto := v_texto||'{4:'||v_salto;
  -- ****************************** cuerpo del mensaje **********************************************
  -- 20: Numero de referencia
  v_texto := v_texto||':20:'||trim(ct.nro_ref_externa)||v_salto;
  -- 23B: Tipo de mensaje
   if nvl(ct.gpi,'N')='S' then
      v_texto := v_texto||':23B:CRED'||v_salto;
   else
      v_texto := v_texto||':23B:'||ct.tip_mensaje||v_salto;
   end if;
  -- 32A: fecha, moneda y monto
  --v_texto := v_texto||':32A:'||to_char(nvl(ct.fec_envio,ct.fec_operacion),'yymmdd')||ct.cod_moneda||trim(replace(to_char(ct.monto,'999999999999.99'),'.',','))||v_salto;
  v_texto := v_texto||':32A:'||to_char(ct.fec_valor,'yymmdd')||ct.cod_moneda||trim(replace(to_char(ct.monto,'999999999999.99'),'.',','))||v_salto;
--ver x tipo de mensaje
  --33B: moneda y monto dependiendo del tipo de cargo pactado
  --wa: 02/01/2015 se ajusta para que no reste los cargos si es del HB,  los cargo se registrarán pero se enviarán cero
  if ct.tip_cargo <> 'OUR' and ct.usu_insercion <> 'HBANK' then
     v_det_cargo := 'S';
     v_texto := v_texto||':33B:'||ct.cod_moneda||trim(replace(to_char(ct.monto - nvl(ct.mto_cargo,0),'999999999999.99'),'.',','))||v_salto;
  elsif ct.tip_cargo <> 'OUR' and ct.usu_insercion ='HBANK' then
     v_det_cargo := 'S';
     v_texto := v_texto||':33B:'||ct.cod_moneda||trim(replace(to_char(ct.monto,'999999999999.99'),'.',','))||v_salto;
  end if;
  -- CROMTASW-1 - MT103 Adaptaciones de Swift 08/2015 V.V.
  If nvl(substr(ct.campo,1,3),'50K') = '50F' then
     v_texto := v_texto||':50F:/'||fug_eli_caracteres(ct.cod_per_solicitante)||v_salto||'1/'||substr(fug_eli_caracteres(ct.nom_solicitante),1,34)||v_salto||'2/'||substr(fug_eli_caracteres(ct.dir_solicitante),1,34)||v_salto||'3/'||substr(fug_eli_caracteres(nvl(ct.nom_ciu_solicitante,fue_obt_des_ciudad(ct.cod_pai_solicitante,ct.cod_ciu_solicitante))||' '||fue_obt_des_pais(ct.cod_pai_solicitante)),1,34)||v_salto;             
  Else
     -- 50K: ordenante  
     v_texto := v_texto||':50K:/'||fug_eli_caracteres(ct.cod_per_solicitante)||v_salto||substr(fug_eli_caracteres(ct.nom_solicitante),1,34)||v_salto||substr(fug_eli_caracteres(ct.dir_solicitante),1,34)||v_salto||substr(fug_eli_caracteres(nvl(ct.nom_ciu_solicitante,fue_obt_des_ciudad(ct.cod_pai_solicitante,ct.cod_ciu_solicitante))||' '||fue_obt_des_pais(ct.cod_pai_solicitante)),1,34)||v_salto;     
  End If;   
  -- 52A: banco ordenante : OJO!! ver los datos esta fijos
  --v_texto := v_texto||':52A:'||'/'||v_nro_cta_corresponsal||v_salto||v_cod_swift||v_salto||fug_obt_nom_entidad||v_salto||'ENCARNACION PY'||v_salto;
  if ct.cod_msj_swift = 103 then
     if ct.cod_bco_cor_contra <> 999 and ct.usu_insercion <> 'HBANK'  then
       -- 56A: Banco intermediario - Corresponsal del banco receptor
       If v_cod_swi_cor_contra is not null then
          --v_texto := v_texto||':56A:'||upper(v_cod_swi_cor_contra)||v_salto||v_nom_bco_cor_contra||v_salto||LTRIM(v_des_ciu_cor_contra||' '||v_des_pai_cor_contra)||v_salto;
          v_texto := v_texto||':56A:'||upper(v_cod_swi_cor_contra)||v_salto; --Se iguala formato al :57A:
       End If;   
       --Cuando se registra el CORRESPONSAL del Banco Operante - Generar    :56D: NOMBRE DEL BANCO SELECCIONADO.
      -- v_texto := v_texto||'56D:'||upper(v_nom_bco_cor_contra)||v_salto;
     --wa:16/01/2015 para Hbank
     elsif ct.usu_insercion = 'HBANK'  then
        -- 56A: Banco intermediario - Corresponsal del banco receptor
         If v_cod_swi_cor_contra is not null then
            --v_texto := v_texto||':56A:'||upper(v_cod_swi_cor_contra)||v_salto||v_nom_bco_cor_contra||v_salto||LTRIM(v_des_ciu_cor_contra||' '||v_des_pai_cor_contra)||v_salto;
            v_texto := v_texto||':56A:'||upper(v_cod_swi_cor_contra)||v_salto;--Se iguala formato al :57A:
         End If;   
       --Cuando se registra el CORRESPONSAL del Banco Operante - Generar    :56D: NOMBRE DEL BANCO SELECCIONADO.
      -- v_texto := v_texto||'56D:'||upper(v_nom_bco_cor_contra)||v_salto;
     end if;
     -- 57A: Banco del beneficiario
     --WA 02/01/2015: Se aplicará en Todos los casos, independiente a 999
     --if ct.cod_banco = 999 then
        if ct.cod_swi_banco is not null then
           --Cuando se tipea 999 en el Codigo del Banco y se registra algo en el campo SWIFT - Generar    :57A: ABCH009 (CAMPO SWIFT)
           v_texto := v_texto||':57A:'||upper(ct.cod_swi_banco)||v_salto; --||v_salto||ct.nom_banco||v_salto||fue_obt_des_ciudad(ct.cod_pai_banco,ct.cod_ciu_banco)||' '||fue_obt_des_pais(ct.cod_pai_banco)||v_salto;
        elsif ct.cod_aba_banco is not null then
        --Cuando se tipea 999 en el Codigo del Banco y se registra algo en el campo ABA - Generar    :57D: 0987765 (CAMPO ABA)
           v_texto := v_texto||':57D:'||upper(ct.cod_aba_banco)||v_salto;
        else
        --Cuando se tipea 999 en el Codigo del Banco NO se registra nada en el campo SWIFT ni el campo ABA - Generar    :57D: NOMBRE DEL BANCO TIPEADO.
          v_texto := v_texto||':57D:'||upper(ct.nom_banco)||v_salto;
        end if;
     -- end if;
     -- CROMTASW-1 - MT103 Adaptaciones de Swift 08/2015 V.V.
     If nvl(substr(ct.campo,7),'59') = '59F' then
        v_texto := v_texto||':59F:' ||'/'||ct.nro_cta_referencia||v_salto||'1/'||substr(fug_eli_caracteres(ct.nom_beneficiario),1,34)||v_salto||'2/'||substr(fug_eli_caracteres(ct.dir_beneficiario),1,34)||v_salto||'3/'||substr(fug_eli_caracteres(nvl(ct.nom_ciu_beneficiario,fue_obt_des_ciudad(ct.cod_pai_beneficiario, ct.cod_ciu_beneficiario))||' '||fue_obt_des_pais(ct.cod_pai_beneficiario)),1,34)||v_salto;        
     Else 
        -- 59 : Datos del beneficiario       
        v_texto := v_texto||':59:' ||'/'||ct.nro_cta_referencia||v_salto||substr(fug_eli_caracteres(ct.nom_beneficiario),1,34)||v_salto||substr(fug_eli_caracteres(substr(ct.dir_beneficiario,1,34)),1,34)||v_salto||substr(fug_eli_caracteres(nvl(ct.nom_ciu_beneficiario,fue_obt_des_ciudad(ct.cod_pai_beneficiario, ct.cod_ciu_beneficiario))||' '||fue_obt_des_pais(ct.cod_pai_beneficiario)),1,34)||v_salto;               
     End If;   
  elsif ct.cod_msj_swift = 202 then
     -- 58 : Datos del banco beneficiario
     v_texto := v_texto||':58A:'||'/'||ct.nro_cta_referencia||v_salto||substr(fug_eli_caracteres(upper(ct.cod_swi_banco)),1,34)||v_salto||substr(fug_eli_caracteres(ct.nom_banco),1,34)||v_salto||substr(fug_eli_caracteres(fue_obt_des_ciudad(ct.cod_pai_banco,ct.cod_ciu_banco)||' '||fue_obt_des_pais(ct.cod_pai_banco)),1,34)||v_salto;
   end if;
  -- 70: COMENTARIO
  /*if ct.observacion is not null then
     v_texto := v_texto||':70:'||upper(ct.observacion)||v_salto;
  end if;*/
  -- 70: COMENTARIO se concatena el campo Observación y Referencia hasta 4 lineas de 35 caracteres
  if ct.observacion is not null or ct.referencia is not null then
     v_tex_comentario := ct.observacion||' '||ct.referencia;
     v_aux_caracteres := length(v_tex_comentario);
     if v_aux_caracteres > 35 then
        While v_posicion <= v_aux_caracteres and v_linea < 4 Loop
          if v_linea = 0 then
             v_texto := v_texto||':70:'||fug_eli_caracteres(upper(LTRIM(substr(v_tex_comentario,0,35))))||v_salto;
          else
              v_texto := v_texto||fug_eli_caracteres(upper(LTRIM(substr(v_tex_comentario,(v_posicion+1),35))))||v_salto;
          end if;     
          v_posicion := v_posicion + 35;
          v_linea := v_linea + 1;
        End Loop;  
     else
        v_texto := v_texto||':70:'||fug_eli_caracteres(upper(LTRIM(v_tex_comentario)))||v_salto;
      end if;  
  end if;
  -- 71A: detalles del cargo
  v_texto := v_texto||':71A:'||ct.tip_cargo||v_salto;
  -- 71F: moneda y monto del cargo
  --WA: 02/01/2015 Sólo sino es HBANK se utiliza esta lógica
  if v_det_cargo = 'S' and ct.usu_insercion <> 'HBANK' then
     --v_texto := v_texto||':71F:'||ct.cod_moneda||trim(replace(to_char(nvl(ct.mto_cargo,0),'999999999999.99'),'.',','))||v_salto;
     v_texto := v_texto||':71F:'||ct.cod_moneda||trim(replace(nvl(ct.mto_cargo,0),'.',','))||v_salto;
  end if;
   -- 72: REFERENCIA
  /*if ct.referencia is not null then
     v_texto := v_texto||':72:'||upper(ct.referencia)||v_salto;
  end if;*/
  -- ********************************* fin del texto ************************************************
  v_texto := v_texto||'-}';
  -- fin de la funcion
  RETURN v_nom_archivo||'~'||v_texto;
END;
/

