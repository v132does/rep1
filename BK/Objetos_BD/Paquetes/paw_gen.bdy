CREATE OR REPLACE PACKAGE BODY IT.PAW_GEN IS

   MSG_OK CONSTANT VARCHAR2(30) := 'OP_APROBADA';
   
   /** Codigo de error generico, Ej. excepciones no manejadas */
   MSG_ERROR CONSTANT VARCHAR2(30) := 'OP_ERROR';

   FUNCTION lf_obtenerTipoContratoCambio(p_cod_tip_operacion IN VARCHAR2)  RETURN VARCHAR2 IS
     
    v_tipo_contrato VARCHAR2(2);
   BEGIN
            IF(p_cod_tip_operacion = '16') THEN
               v_tipo_contrato := 'C';
            ELSIF(p_cod_tip_operacion = '30') THEN
               v_tipo_contrato := 'V';
            ELSIF(p_cod_tip_operacion = '61') THEN
               v_tipo_contrato := 'AC';  
            ELSIF(p_cod_tip_operacion = '47') THEN
               v_tipo_contrato := 'AV';                                 
            END IF;
            RETURN v_tipo_contrato;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   
   FUNCTION lf_obtenerCodOpeContrato(p_tipo_contrato         IN VARCHAR2,
                                     p_cod_tip_mensaje       IN VARCHAR2)  RETURN VARCHAR2 IS
      v_cod_operaciones VARCHAR2(5);

   BEGIN
                 
           IF p_tipo_contrato = 'C' THEN
              v_cod_operaciones := '16';
           ELSIF p_tipo_contrato = 'V' THEN
              v_cod_operaciones := '30';
           ELSIF p_tipo_contrato = 'A' THEN
              v_cod_operaciones := '61';
              --la operacion venta depende de la operacion que se esté realizando
              IF p_cod_tip_mensaje = '036' THEN
                v_cod_operaciones := v_cod_operaciones || ',' || '47';
              END IF;
              
           END IF;
       RETURN v_cod_operaciones;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;   
  
FUNCTION fu_obt_customer(p_nro_documento IN VARCHAR2 default null,
                         p_cod_tip_documento IN VARCHAR2 default null
) RETURN typ_datCustomer IS
 v_retorno       TYP_DATCUSTOMER := TYP_DATCUSTOMER();
 v_tipo          varchar2(1);
 v_pri_nombre    ba_personas.nom_completo%type;
 v_seg_nombre    ba_per_fisicas.seg_nombre%type;
 v_apellido      varchar2(100);
 v_nro_documeto  ba_personas.nro_documento%type;
 v_cod_tip_documento ba_personas.cod_tip_documento%type;
 v_cod_persona   ba_personas.cod_persona%type;
 v_fec_nacimiento date;
 v_fec_formateado varchar(20);
 v_tip_documento varchar2(100);
 v_des_documento varchar2(100);
 v_est_civil     ba_per_fisicas.est_civil%type;
 v_id_est_civil  varchar2(100);
 v_det_est_civil varchar2(100);
 v_cod_sexo      varchar2(30);
 v_des_sexo      varchar2(100);
 v_est_cliente   varchar2(1);
 v_cod_oficina   varchar2(100);
 v_oficina       varchar2(100);
 v_es_cliente    varchar2(1):=null;
 v_es_persona    varchar2(1):=null;
 v_es_valido     varchar2(1):= null;
 v_cod_pais_iso      varchar2(10):=null;
   /*
    --Para p_cod_tip_documento :
    --Valores posibles
    CI  -> Cedula de Identidad
    RUC -> Ruc
    CRC -> Cédula de Identidad Extranjera
    PAS -> Pasaporte
    DNI -> Documento Nacional de Identidad
    CRP -> Cértificado de Residencia Permanente
    COD -> Codigo Interno
    --Para isClient
       - Si el cliente ='S'
       - Si es persona ='N'
       - Sino Existe = null
    */
BEGIN
  --Validamos que ingrese un filtro para Buscar
  if p_nro_documento is null or  p_cod_tip_documento is null then
       paw_uti.pr_mensajeusuario('VAL_PENTRADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);
       RETURN v_retorno;
  end if;


  --Validamos tipo de documento
  if p_cod_tip_documento is not null then
     v_es_valido:='N';
     BEGIN
        select 'S'
          into v_es_valido
           from  ba_tip_documentos c
              where upper(c.abreviatura)= upper(p_cod_tip_documento)
                 and rownum=1;
     EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_es_valido:='N';
              paw_uti.pr_mensajeusuario('VAL_PENTRADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);
              RETURN v_retorno;
            WHEN OTHERS THEN
              v_es_valido:='N';
              paw_uti.pr_mensajeusuario('VAL_PENTRADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);
              RETURN v_retorno;
     END;

  end if;


  --Buscamos si es persona física o juridica y si existe
  v_tipo:='N' ;
  v_pri_nombre:=null;
  v_cod_persona:= null;
  v_seg_nombre:= null;
  v_apellido:= null;
  v_nro_documeto:= null;
  v_tip_documento:= null;
  v_des_documento:= null;
  v_est_civil:= null;
  v_id_est_civil:= null;
  v_det_est_civil:= null;
  v_cod_sexo:= null;
  v_des_sexo:= null;
  v_cod_sexo:= null;
  v_oficina:= null;
  v_est_cliente:=null;
  v_cod_oficina:=null;
  v_es_cliente:=null;
  v_es_persona:=null;
  BEGIN
    select a.tipo,a.cod_persona, a.cod_tip_documento,a.nro_documento
     into v_tipo, v_cod_persona, v_cod_tip_documento, v_nro_documeto
      from ba_personas a , ge_cta_clientes b, ba_tip_documentos c
       where a.nro_documento = nvl(p_nro_documento,a.nro_documento)
          and a.cod_persona= b.cod_persona
          and a.cod_tip_documento=c.cod_tip_documento
          and upper(c.abreviatura)= upper(nvl(p_cod_tip_documento,c.abreviatura))
          and rownum=1;
          v_es_cliente:='S';
          v_es_persona:='S';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_tipo:='N' ;
      --Buscamos si es persona
      BEGIN
         select a.tipo,a.cod_persona, a.cod_tip_documento,a.nro_documento
            into v_tipo, v_cod_persona, v_cod_tip_documento, v_nro_documeto
               from ba_personas a, ba_tip_documentos b
                   where a.nro_documento = nvl(p_nro_documento,a.nro_documento)
                      and a.cod_tip_documento=b.cod_tip_documento
                      and b.abreviatura= nvl(p_cod_tip_documento,b.abreviatura)
                            and rownum=1;
           v_es_cliente:='N';
           v_es_persona:='S';
      EXCEPTION
         when no_data_found then
            v_es_cliente:=null;
            v_es_persona:='N';
      END;

    WHEN OTHERS THEN
      v_tipo:='N' ;
  END;

  if v_es_cliente is not null and v_es_valido='S' and v_tipo='F' then --Se ajusta para envio de personas fisicas unicamente
        begin
         v_cod_oficina:= fug_obt_ofi_cliente(v_cod_persona);
        exception
         when others then
           v_cod_oficina:= NULL;
         end;
        IF v_cod_oficina IS NOT NULL THEN
           v_oficina:= fue_obt_des_oficina(v_cod_oficina);
        ELSE
           v_oficina:=NULL;
        END IF;
        if v_tipo='F' then
           --Es persona fisica
               BEGIN
                  select a.pri_nombre,a.seg_nombre,trim(trim(a.pri_apellido)||' '||trim(a.seg_apellido)),a.fec_nacimiento,a.est_civil,a.cod_sexo
                   into  v_pri_nombre, v_seg_nombre,v_apellido,v_fec_nacimiento, v_est_civil,v_cod_sexo
                    from ba_per_fisicas a
                     where a.cod_persona= v_cod_persona;
                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                    v_pri_nombre:=null;
                    v_seg_nombre:=null;
                    v_apellido:=null;
                  WHEN OTHERS THEN
                    v_pri_nombre:=null;
                    v_seg_nombre:=null;
                    v_apellido:=null;
                END;
                      --**** Para Estado Civil
                        --Valores Posibles
                      /*
                      SINGLE: Indicator marital status bachelor.
                      MARRIED: Indicator marital status married.
                      DIVORCED: Indicator marital status divorced.
                      COHABITANT: Indicator marital status cohabitant.
                      SEPERATED: Indicator of persons legally married, but no longer living with their spouse and has not obtained a divorce.
                      WIDOWED: Indicator of someone who has lost her spouse to death and hasn't remarried.
                      MARRIED_WITH_SEPARATED_PROPERTY: Indicator marital status married with separated property.
                      MARRIED_WITHOUT_SEPARATED_PROPERTY: Indicator marital status married without separated property.
                      CIVIL_UNION_AGREEMENT_WITH_SEPARATED_PROPERTY: Indicator marital status "union" with separated property through the civil agreement.
                      CIVIL_UNION_AGREEMENT_WITHOUT_SEPARATED_PROPERTY: Indicator marital status "union" without separated property through the civil agreement.
                      MARRIED_WITH_COMMUNITY_PROPERTY: Indicator marital status married with community property.
                      NO_INFO: Without information registered in systems.
                      ---Equivalencias con el CORE
                      Soltero/a                          S-->SINGLE
                      Casado/a sin separacion de bienes  C-->MARRIED_WITHOUT_SEPARATED_PROPERTY
                      Viudo/a                            V-->WIDOWED
                      Divorciado/a                      D-->DIVORCED
                      Casado/a con separación de Bienes  B-->MARRIED_WITH_SEPARATED_PROPERTY
                      Union de Hecho                    U-->COHABITANT
                      Separado/a                        E-->SEPERATED
                      Otros                              O-->NO_INFO
                      */
                      v_id_est_civil:= case v_est_civil
                                          when 'S' then 'SINGLE'
                                          when 'C' then 'MARRIED_WITHOUT_SEPARATED_PROPERTY'
                                          when 'V' then 'WIDOWED'
                                          when 'D' then 'DIVORCED'
                                          when 'B' then 'MARRIED_WITH_SEPARATED_PROPERTY'
                                          when 'U' then 'COHABITANT'
                                          when 'E' then 'SEPERATED'
                                          when 'O' then 'NO_INFO'
                                          else null
                                        END;

                      v_det_est_civil:= case v_id_est_civil
                                          when 'SINGLE' then 'Soltero/a'
                                          when 'MARRIED_WITHOUT_SEPARATED_PROPERTY'  then 'Casado/a sin separacion de bienes'
                                          when 'WIDOWED' then 'Viudo/a'
                                          when 'DIVORCED' then 'Divorciado/a'
                                          when 'MARRIED_WITH_SEPARATED_PROPERTY' then 'Casado/a con separación de Bienes'
                                          when 'COHABITANT' then 'Union de Hecho'
                                          when 'SEPERATED' then 'Separado/a'
                                          when 'NO_INFO' then 'Otros  '
                                          else null
                                        END;
                      /*Valores Posibles
                        MALE: Male.
                        FEMALE: Female.
                        *** Equivalencias con el CORE
                        M - Masculino  -> MALE
                        F-  Femenino   -> FEMALE

                        */
                     v_cod_sexo:= case v_cod_sexo
                                when 'M' then 'MALE'
                                when 'F' then 'FEMALE'
                                else null
                              end;
                      v_des_sexo:= case v_cod_sexo
                                when 'MALE' then 'Masculino'
                                when 'FEMALE' then 'Femenino'
                                else null
                              end;

        elsif v_tipo='J' then
              --Es persona juridica, ya tenemos primer nombre, lo demas nada
              v_pri_nombre:=null;
              v_seg_nombre:=null;
              v_apellido:=null;
              BEGIN
                    select a.fec_apertura,a.raz_social
                     into  v_fec_nacimiento,v_pri_nombre
                      from ba_per_juridicas a
                       where a.cod_persona= v_cod_persona;
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      v_pri_nombre:=null;
                      v_fec_nacimiento:=null;
                      v_apellido:=null;
                    WHEN OTHERS THEN
                      v_pri_nombre:=null;
                      v_fec_nacimiento:=null;
                      v_apellido:=null;
                  END;
          end if;
          --**** Para tipo de Documento
          --Valores Posibles
          /*
          PASSPORT: Identifier document passport.
          NIF: Identifier document fiscal identification number.
          RESIDENTIAL_PASS: Identifier document residence.
          DNI: Identifier national identity document.
          RUC: Identifier document single tax registration.
          NIT: Identifier document tax identification number.
          CURP: Unique Population Registry Code.
          INE: National Electoral Institute Code.
          DL: Drivers License Number.
          STATE_ID: State Issued Identification.
          DIPLOMATIC: Identifier document issued to members of diplomatic missions residing in.
          FOREIGNERS: Identifier card for foreign residents.
          MILITARY: Identifier document that accredits the military situation.
          POLICE: Police Identification Card Identifier.
          RUT: Identifier national identity document.
          ---Equivalencias con el CORE
          1  CEDULA DE IDENTIDAD PARAGUAYA  CI      --> DNI
          2  PASAPORTE  PAS                         -->PASSPORT
          3  CERTIFICADO RESIDENCIA PERMANENTE  CRP -->RESIDENTIAL_PASS
          5  CEDULA DE IDENTIDAD EXTRANJERA  CRC   --> FOREIGNERS
          6  REGISTRO UNICO DEL CONTRIBUYENTE  RUC --> RUC
          10  SIN DOCUMENTO  SIN
          38  DUPLICADO 1  DUP                     --> DNI
          39  DUPLICADO 2  DUP                     --> DNI
          40  DUPLICADO 3  DUP                     --> DNI
          41  OTROS  OTR
          42  SWIFT  PJ
          43  DOCUMENTO NACIONAL DE IDENTIDAD  DNI --> DNI
          */
          v_tip_documento:= case v_cod_tip_documento
                              when 1 then 'DNI'
                              when 2 then 'PASSPORT'
                              when 3 then 'RESIDENTIAL_PASS'
                              when 5 then 'FOREIGNERS'
                              when 6 then 'RUC'
                              when 38 then 'DNI'
                              when 39 then 'DNI'
                              when 40 then 'DNI'
                              when 43 then 'DNI'
                              else null
                            END;

          v_des_documento:= case v_tip_documento
                              when 'DNI' then 'Documento Nacional de Identidad'
                              when 'PASSPORT'  then 'Pasaporte'
                              when 'RESIDENTIAL_PASS' then 'Certificado Residencia Permanente'
                              when 'FOREIGNERS' then 'Cedula de identidad Extranjera        '
                              when 'RUC' then 'Registro Unico de Contribuyente'
                              else null
                            END;
         v_est_cliente:= case fug_es_cliente(v_cod_persona)
                         when 'N' then 'N'
                         when 'S' then 'S'
                         end ;
         if v_est_cliente='N' and  v_es_persona='S'  then
           --Ya no es Cliente, es sólo persona
           v_es_cliente:='N';
         elsif  v_est_cliente='N' and  v_es_persona ='N'  then
           v_es_cliente:=null;
         end if;
         --Fecha de Nacimiento/Apertura "2016-09-02"
         v_fec_formateado:= to_char(v_fec_nacimiento,'yyyy-mm-dd');

           --Para retornar cod_pais de tipo de documento
            v_cod_pais_iso := null;
            BEGIN
                select b.cod_pai_iso
                  into v_cod_pais_iso
                   from  ba_personas a, ba_paises b
                      where a.cod_pai_documento=b.cod_pais
                         and a.cod_persona= v_cod_persona
                         and rownum=1;
             EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      v_cod_pais_iso := null;
                     WHEN OTHERS THEN
                      v_cod_pais_iso := null;
             END;
   end if;
   --Si es persona Juridica y tiene cod_persona(Existe), enviamos espacio en blanco en vez de null
   if v_apellido is null and v_tipo='J' and v_cod_persona is not null then
     v_apellido:= ' ';
   end if;
   -- ******Cargamos salida
   v_retorno.customerId           :=v_cod_persona;
   v_retorno.firstName            :=v_pri_nombre;
   v_retorno.middleName           :=v_seg_nombre;
   v_retorno.lastName             :=v_apellido;
   v_retorno.suffix               :=null;
   v_retorno.birthDataCity        :=null;
   v_retorno.birthDataStateid     :=null;
   v_retorno.birthDataStatename   :=null;
   v_retorno.birthDataCountryid   :=null;
   v_retorno.birthDataCountryname :=null;
   v_retorno.birthDataBirthDate   :=v_fec_formateado;
   v_retorno.nationalityid        :=null;
   v_retorno.nationalityName      :=null;
   v_retorno.iDdocumentTypeid     :=v_tip_documento;
   v_retorno.iDdocumentTypeName   :=v_des_documento;
   v_retorno.iDcountryid          :=v_cod_pais_iso;--null;
   v_retorno.iDcountryname        :=null;
   v_retorno.iDstateid            :=null;
   v_retorno.iDstatename          :=null;
   v_retorno.iDstatusid           :=null;
   v_retorno.iDstatusname         :=null;
   v_retorno.iDissueDate          :=null;
   v_retorno.iDexpirationDate     :=null;
   v_retorno.iDdocumentNumber     :=null;
   v_retorno.membershipDate       :=null;
   v_retorno.lastAccessDate       :=null;
   v_retorno.personalTitleid      :=null;
   v_retorno.personalTitlename    :=null;
   v_retorno.maritalStatusid      :=v_id_est_civil;
   v_retorno.maritalStatusname    :=v_det_est_civil;
   v_retorno.genderid             :=v_cod_sexo;
   v_retorno.gendername           :=v_des_sexo;
   v_retorno.bankId               :=null;
   v_retorno.bankname             :=null;
   v_retorno.bankbranchId         :=v_cod_oficina; --Codigo de Oficina
   v_retorno.bankbranchname       :=v_oficina;    --Des. Oficina
   v_retorno.bankbranchcostCenter :=null;
   v_retorno.residencecountryid   :=null;
   v_retorno.residencecountryname :=null;
   v_retorno.residenceTypeid      :=null;
   v_retorno.residenceTypename    :=null;
   v_retorno.residencestartDate   :=null;
   v_retorno.pEPid                :=null;
   v_retorno.pEPfullName          :=null;
   v_retorno.pEPposition          :=null;
   v_retorno.socialSecurityNumber :=null;
   v_retorno.isClient             := v_es_cliente;
   paw_uti.pr_mensajeusuario('OP_APROBADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);

  return v_retorno;
END;

FUNCTION fu_obt_customers(p_nro_documento IN VARCHAR2 default null,
                         p_cod_tip_documento IN VARCHAR2 default null
) RETURN typ_datCustomer IS
 v_retorno       TYP_DATCUSTOMER := TYP_DATCUSTOMER();
 v_tipo          varchar2(1);
 v_pri_nombre    ba_personas.nom_completo%type;
 v_seg_nombre    ba_per_fisicas.seg_nombre%type;
 v_apellido      varchar2(100);
 v_nro_documeto  ba_personas.nro_documento%type;
 v_cod_tip_documento ba_personas.cod_tip_documento%type;
 v_cod_persona   ba_personas.cod_persona%type;
 v_fec_nacimiento date;
 v_fec_formateado varchar(20);
 v_tip_documento varchar2(100);
 v_des_documento varchar2(100);
 v_est_civil     ba_per_fisicas.est_civil%type;
 v_id_est_civil  varchar2(100);
 v_det_est_civil varchar2(100);
 v_cod_sexo      varchar2(30);
 v_des_sexo      varchar2(100);
 v_est_cliente   varchar2(1);
 v_cod_oficina   varchar2(100);
 v_oficina       varchar2(100);
 v_es_cliente    varchar2(1):=null;
 v_es_persona    varchar2(1):=null;
 v_es_valido     varchar2(1):= null;
 v_cod_pais_iso      varchar2(10):=null;
   /*
    --Para p_cod_tip_documento :
    --Valores posibles
    CI  -> Cedula de Identidad
    RUC -> Ruc
    CRC -> Cédula de Identidad Extranjera
    PAS -> Pasaporte
    DNI -> Documento Nacional de Identidad
    CRP -> Cértificado de Residencia Permanente
    COD -> Codigo Interno
    --Para isClient
       - Si el cliente ='S'
       - Si es persona ='N'
       - Sino Existe = null
    */
BEGIN
  --Validamos que ingrese un filtro para Buscar
  if p_nro_documento is null or  p_cod_tip_documento is null then
       paw_uti.pr_mensajeusuario('VAL_PENTRADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);
       RETURN v_retorno;
  end if;


  --Validamos tipo de documento
  if p_cod_tip_documento is not null then
     v_es_valido:='N';
     BEGIN
        select 'S'
          into v_es_valido
           from  ba_tip_documentos c
              where upper(c.abreviatura)= upper(p_cod_tip_documento)
                 and rownum=1;
     EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_es_valido:='N';
              paw_uti.pr_mensajeusuario('VAL_PENTRADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);
              RETURN v_retorno;
            WHEN OTHERS THEN
              v_es_valido:='N';
              paw_uti.pr_mensajeusuario('VAL_PENTRADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);
              RETURN v_retorno;
     END;

  end if;


  --Buscamos si es persona física o juridica y si existe
  v_tipo:='N' ;
  v_pri_nombre:=null;
  v_cod_persona:= null;
  v_seg_nombre:= null;
  v_apellido:= null;
  v_nro_documeto:= null;
  v_tip_documento:= null;
  v_des_documento:= null;
  v_est_civil:= null;
  v_id_est_civil:= null;
  v_det_est_civil:= null;
  v_cod_sexo:= null;
  v_des_sexo:= null;
  v_cod_sexo:= null;
  v_oficina:= null;
  v_est_cliente:=null;
  v_cod_oficina:=null;
  v_es_cliente:=null;
  v_es_persona:=null;
  BEGIN
    select a.tipo,a.cod_persona, a.cod_tip_documento,a.nro_documento
     into v_tipo, v_cod_persona, v_cod_tip_documento, v_nro_documeto
      from ba_personas a , ge_cta_clientes b, ba_tip_documentos c
       where a.nro_documento = nvl(p_nro_documento,a.nro_documento)
          and a.cod_persona= b.cod_persona
          and a.cod_tip_documento=c.cod_tip_documento
          and upper(c.abreviatura)= upper(nvl(p_cod_tip_documento,c.abreviatura))
          and a.tipo = 'F'
          and rownum=1;
          v_es_cliente:='S';
          v_es_persona:='S';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_tipo:='N' ;
      --Buscamos si es persona
      BEGIN
         select a.tipo,a.cod_persona, a.cod_tip_documento,a.nro_documento
            into v_tipo, v_cod_persona, v_cod_tip_documento, v_nro_documeto
               from ba_personas a, ba_tip_documentos b
                   where a.nro_documento = nvl(p_nro_documento,a.nro_documento)
                      and a.cod_tip_documento=b.cod_tip_documento
                      and b.abreviatura= nvl(p_cod_tip_documento,b.abreviatura)
                      and a.tipo = 'F'
                            and rownum=1;
           v_es_cliente:='N';
           v_es_persona:='S';
      EXCEPTION
         when no_data_found then
            v_es_cliente:=null;
            v_es_persona:='N';
      END;

    WHEN OTHERS THEN
      v_tipo:='N' ;
  END;

  if v_es_cliente is not null and v_es_valido='S' and v_tipo='F' then --Se ajusta para envio de personas fisicas unicamente
        begin
         v_cod_oficina:= fug_obt_ofi_cliente(v_cod_persona);
        exception
         when others then
           v_cod_oficina:= NULL;
         end;
        IF v_cod_oficina IS NOT NULL THEN
           v_oficina:= fue_obt_des_oficina(v_cod_oficina);
        ELSE
           v_oficina:=NULL;
        END IF;
        if v_tipo='F' then
           --Es persona fisica
               BEGIN
                  select a.pri_nombre,a.seg_nombre,trim(trim(a.pri_apellido)||' '||trim(a.seg_apellido)),a.fec_nacimiento,a.est_civil,a.cod_sexo
                   into  v_pri_nombre, v_seg_nombre,v_apellido,v_fec_nacimiento, v_est_civil,v_cod_sexo
                    from ba_per_fisicas a
                     where a.cod_persona= v_cod_persona;
                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                    v_pri_nombre:=null;
                    v_seg_nombre:=null;
                    v_apellido:=null;
                  WHEN OTHERS THEN
                    v_pri_nombre:=null;
                    v_seg_nombre:=null;
                    v_apellido:=null;
                END;
                      --**** Para Estado Civil
                        --Valores Posibles
                      /*
                      SINGLE: Indicator marital status bachelor.
                      MARRIED: Indicator marital status married.
                      DIVORCED: Indicator marital status divorced.
                      COHABITANT: Indicator marital status cohabitant.
                      SEPERATED: Indicator of persons legally married, but no longer living with their spouse and has not obtained a divorce.
                      WIDOWED: Indicator of someone who has lost her spouse to death and hasn't remarried.
                      MARRIED_WITH_SEPARATED_PROPERTY: Indicator marital status married with separated property.
                      MARRIED_WITHOUT_SEPARATED_PROPERTY: Indicator marital status married without separated property.
                      CIVIL_UNION_AGREEMENT_WITH_SEPARATED_PROPERTY: Indicator marital status "union" with separated property through the civil agreement.
                      CIVIL_UNION_AGREEMENT_WITHOUT_SEPARATED_PROPERTY: Indicator marital status "union" without separated property through the civil agreement.
                      MARRIED_WITH_COMMUNITY_PROPERTY: Indicator marital status married with community property.
                      NO_INFO: Without information registered in systems.
                      ---Equivalencias con el CORE
                      Soltero/a                          S-->SINGLE
                      Casado/a sin separacion de bienes  C-->MARRIED_WITHOUT_SEPARATED_PROPERTY
                      Viudo/a                            V-->WIDOWED
                      Divorciado/a                      D-->DIVORCED
                      Casado/a con separación de Bienes  B-->MARRIED_WITH_SEPARATED_PROPERTY
                      Union de Hecho                    U-->COHABITANT
                      Separado/a                        E-->SEPERATED
                      Otros                              O-->NO_INFO
                      */
                      v_id_est_civil:= case v_est_civil
                                          when 'S' then 'SINGLE'
                                          when 'C' then 'MARRIED_WITHOUT_SEPARATED_PROPERTY'
                                          when 'V' then 'WIDOWED'
                                          when 'D' then 'DIVORCED'
                                          when 'B' then 'MARRIED_WITH_SEPARATED_PROPERTY'
                                          when 'U' then 'COHABITANT'
                                          when 'E' then 'SEPERATED'
                                          when 'O' then 'NO_INFO'
                                          else null
                                        END;

                      v_det_est_civil:= case v_id_est_civil
                                          when 'SINGLE' then 'Soltero/a'
                                          when 'MARRIED_WITHOUT_SEPARATED_PROPERTY'  then 'Casado/a sin separacion de bienes'
                                          when 'WIDOWED' then 'Viudo/a'
                                          when 'DIVORCED' then 'Divorciado/a'
                                          when 'MARRIED_WITH_SEPARATED_PROPERTY' then 'Casado/a con separación de Bienes'
                                          when 'COHABITANT' then 'Union de Hecho'
                                          when 'SEPERATED' then 'Separado/a'
                                          when 'NO_INFO' then 'Otros  '
                                          else null
                                        END;
                      /*Valores Posibles
                        MALE: Male.
                        FEMALE: Female.
                        *** Equivalencias con el CORE
                        M - Masculino  -> MALE
                        F-  Femenino   -> FEMALE

                        */
                     v_cod_sexo:= case v_cod_sexo
                                when 'M' then 'MALE'
                                when 'F' then 'FEMALE'
                                else null
                              end;
                      v_des_sexo:= case v_cod_sexo
                                when 'MALE' then 'Masculino'
                                when 'FEMALE' then 'Femenino'
                                else null
                              end;
          end if;
          --**** Para tipo de Documento
          --Valores Posibles
          /*
          PASSPORT: Identifier document passport.
          NIF: Identifier document fiscal identification number.
          RESIDENTIAL_PASS: Identifier document residence.
          DNI: Identifier national identity document.
          RUC: Identifier document single tax registration.
          NIT: Identifier document tax identification number.
          CURP: Unique Population Registry Code.
          INE: National Electoral Institute Code.
          DL: Drivers License Number.
          STATE_ID: State Issued Identification.
          DIPLOMATIC: Identifier document issued to members of diplomatic missions residing in.
          FOREIGNERS: Identifier card for foreign residents.
          MILITARY: Identifier document that accredits the military situation.
          POLICE: Police Identification Card Identifier.
          RUT: Identifier national identity document.
          ---Equivalencias con el CORE
          1  CEDULA DE IDENTIDAD PARAGUAYA  CI      --> DNI
          2  PASAPORTE  PAS                         -->PASSPORT
          3  CERTIFICADO RESIDENCIA PERMANENTE  CRP -->RESIDENTIAL_PASS
          5  CEDULA DE IDENTIDAD EXTRANJERA  CRC   --> FOREIGNERS
          6  REGISTRO UNICO DEL CONTRIBUYENTE  RUC --> RUC
          10  SIN DOCUMENTO  SIN
          38  DUPLICADO 1  DUP                     --> DNI
          39  DUPLICADO 2  DUP                     --> DNI
          40  DUPLICADO 3  DUP                     --> DNI
          41  OTROS  OTR
          42  SWIFT  PJ
          43  DOCUMENTO NACIONAL DE IDENTIDAD  DNI --> DNI
          */
          v_tip_documento:= case v_cod_tip_documento
                              when 1 then 'DNI'
                              when 2 then 'PASSPORT'
                              when 3 then 'RESIDENTIAL_PASS'
                              when 5 then 'FOREIGNERS'
                              when 6 then 'RUC'
                              when 38 then 'DNI'
                              when 39 then 'DNI'
                              when 40 then 'DNI'
                              when 43 then 'DNI'
                              else null
                            END;

          v_des_documento:= case v_tip_documento
                              when 'DNI' then 'Documento Nacional de Identidad'
                              when 'PASSPORT'  then 'Pasaporte'
                              when 'RESIDENTIAL_PASS' then 'Certificado Residencia Permanente'
                              when 'FOREIGNERS' then 'Cedula de identidad Extranjera        '
                              when 'RUC' then 'Registro Unico de Contribuyente'
                              else null
                            END;
         v_est_cliente:= case fug_es_cliente(v_cod_persona)
                         when 'N' then 'N'
                         when 'S' then 'S'
                         end ;
         if v_est_cliente='N' and  v_es_persona='S'  then
           --Ya no es Cliente, es sólo persona
           v_es_cliente:='N';
         elsif  v_est_cliente='N' and  v_es_persona ='N'  then
           v_es_cliente:=null;
         end if;
         --Fecha de Nacimiento/Apertura "2016-09-02"
         v_fec_formateado:= to_char(v_fec_nacimiento,'yyyy-mm-dd');

           --Para retornar cod_pais de tipo de documento
            v_cod_pais_iso := null;
            BEGIN
                select b.cod_pai_iso
                  into v_cod_pais_iso
                   from  ba_personas a, ba_paises b
                      where a.cod_pai_documento=b.cod_pais
                         and a.cod_persona= v_cod_persona
                         and a.tipo = 'F'
                         and rownum=1;
             EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      v_cod_pais_iso := null;
                     WHEN OTHERS THEN
                      v_cod_pais_iso := null;
             END;
   end if;

   -- ******Cargamos salida
   v_retorno.customerId           :=v_cod_persona;
   v_retorno.firstName            :=v_pri_nombre;
   v_retorno.middleName           :=v_seg_nombre;
   v_retorno.lastName             :=v_apellido;
   v_retorno.suffix               :=null;
   v_retorno.birthDataCity        :=null;
   v_retorno.birthDataStateid     :=null;
   v_retorno.birthDataStatename   :=null;
   v_retorno.birthDataCountryid   :=null;
   v_retorno.birthDataCountryname :=null;
   v_retorno.birthDataBirthDate   :=v_fec_formateado;
   v_retorno.nationalityid        :=null;
   v_retorno.nationalityName      :=null;
   v_retorno.iDdocumentTypeid     :=v_tip_documento;
   v_retorno.iDdocumentTypeName   :=v_des_documento;
   v_retorno.iDcountryid          :=v_cod_pais_iso;--null;
   v_retorno.iDcountryname        :=null;
   v_retorno.iDstateid            :=null;
   v_retorno.iDstatename          :=null;
   v_retorno.iDstatusid           :=null;
   v_retorno.iDstatusname         :=null;
   v_retorno.iDissueDate          :=null;
   v_retorno.iDexpirationDate     :=null;
   v_retorno.iDdocumentNumber     :=null;
   v_retorno.membershipDate       :=null;
   v_retorno.lastAccessDate       :=null;
   v_retorno.personalTitleid      :=null;
   v_retorno.personalTitlename    :=null;
   v_retorno.maritalStatusid      :=v_id_est_civil;
   v_retorno.maritalStatusname    :=v_det_est_civil;
   v_retorno.genderid             :=v_cod_sexo;
   v_retorno.gendername           :=v_des_sexo;
   v_retorno.bankId               :=null;
   v_retorno.bankname             :=null;
   v_retorno.bankbranchId         :=v_cod_oficina; --Codigo de Oficina
   v_retorno.bankbranchname       :=v_oficina;    --Des. Oficina
   v_retorno.bankbranchcostCenter :=null;
   v_retorno.residencecountryid   :=null;
   v_retorno.residencecountryname :=null;
   v_retorno.residenceTypeid      :=null;
   v_retorno.residenceTypename    :=null;
   v_retorno.residencestartDate   :=null;
   v_retorno.pEPid                :=null;
   v_retorno.pEPfullName          :=null;
   v_retorno.pEPposition          :=null;
   v_retorno.socialSecurityNumber :=null;
   v_retorno.isClient             := v_es_cliente;
   paw_uti.pr_mensajeusuario('OP_APROBADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);

  return v_retorno;
END;


FUNCTION fu_obt_customerid(
  p_cod_persona IN VARCHAR2 default null
) RETURN typ_datCustomer IS
 v_retorno       TYP_DATCUSTOMER := TYP_DATCUSTOMER();
 v_tipo          varchar2(1);
 v_pri_nombre    ba_personas.nom_completo%type;
 v_seg_nombre    ba_per_fisicas.seg_nombre%type;
 v_apellido      varchar2(100);
 v_nro_documeto  ba_personas.nro_documento%type;
 v_cod_tip_documento ba_personas.cod_tip_documento%type;
 v_cod_persona   ba_personas.cod_persona%type;
 v_fec_nacimiento date;
 v_fec_formateado varchar(20);
 v_tip_documento varchar2(100);
 v_des_documento varchar2(100);
 v_est_civil     ba_per_fisicas.est_civil%type;
 v_id_est_civil  varchar2(100);
 v_det_est_civil varchar2(100);
 v_cod_sexo      varchar2(30);
 v_des_sexo      varchar2(100);
 v_est_cliente   varchar2(1);
 v_cod_oficina   varchar2(100);
 v_oficina       varchar2(100);
 v_es_cliente    varchar2(1):=null;
 v_es_persona   varchar2(1):=null;
 v_fec_membresia varchar(10);
 v_cod_pais number(3);

 /*--Para p_cod_tip_documento :
    --Valores posibles
    CI  -> Cedula de Identidad
    RUC -> Ruc
    CRC -> Cédula de Identidad Extranjera
    PAS -> Pasaporte
    DNI -> Documento Nacional de Identidad
    CRP -> Cértificado de Residencia Permanente
    COD -> Codigo Interno
    --Para isClient
       - Si el cliente ='S'
       - Si es persona ='N'
       - Sino Existe = null*/
BEGIN

  --Validamos que ingrese un filtro para Buscar
  if p_cod_persona is null then
       paw_uti.pr_mensajeusuario('VAL_PENTRADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);
       RETURN v_retorno;
  end if;
  --Buscamos si es persona física o juridica y si existe
  v_tipo:='N' ;
  v_pri_nombre:=null;
  v_cod_persona:= null;
  v_seg_nombre:= null;
  v_apellido:= null;
  v_nro_documeto:= null;
  v_tip_documento:= null;
  v_des_documento:= null;
  v_est_civil:= null;
  v_id_est_civil:= null;
  v_det_est_civil:= null;
  v_cod_sexo:= null;
  v_des_sexo:= null;
  v_cod_sexo:= null;
  v_oficina:= null;
  v_est_cliente:=null;
  v_cod_oficina:=null;
  v_es_cliente:=null;
  v_es_persona:=null;

  BEGIN
    select a.tipo,a.cod_persona, a.cod_tip_documento,a.nro_documento, a.cod_pais
     into v_tipo, v_cod_persona, v_cod_tip_documento, v_nro_documeto, v_cod_pais
      from ba_personas a , ge_cta_clientes b
       where a.cod_persona= nvl(p_cod_persona,a.cod_persona)
         and a.cod_persona= b.cod_persona
          and rownum=1;
          v_es_cliente:='S';
           v_es_persona:='S';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
         --Buscamos si es persona
      BEGIN
         select a.tipo,a.cod_persona, a.cod_tip_documento,a.nro_documento, a.cod_pais
            into v_tipo, v_cod_persona, v_cod_tip_documento, v_nro_documeto, v_cod_pais
               from ba_personas a
                   where a.cod_persona = nvl(p_cod_persona,a.cod_persona)
                     and rownum=1;
                        v_es_cliente:='N';
                         v_es_persona:='S';
      EXCEPTION
         when no_data_found then
            v_es_cliente:= null;
             v_es_persona:='N';
      END;
    WHEN OTHERS THEN
      v_tipo:='N' ;
  END;


  if v_es_cliente is not null then

   BEGIN
      SELECT to_char(FEC_INGRESO, 'YYYY-MM-DD')
        INTO v_fec_membresia
        FROM ge_clientes
       WHERE COD_PERSONA = p_cod_persona;
   EXCEPTION
      WHEN OTHERS THEN
         v_fec_membresia := NULL;
   END;
   BEGIN
      v_cod_oficina := fug_obt_ofi_cliente(v_cod_persona);
   EXCEPTION
      WHEN OTHERS THEN
         v_cod_oficina := NULL;
   END;
   IF v_cod_oficina IS NOT NULL THEN
      v_oficina := fue_obt_des_oficina(v_cod_oficina);
   ELSE
      v_oficina := NULL;
   END IF;

      if v_tipo='F' then
         --Es persona fisica
             BEGIN
                select a.pri_nombre,a.seg_nombre,trim(trim(a.pri_apellido)||' '||trim(a.seg_apellido)),a.fec_nacimiento,a.est_civil,a.cod_sexo
                 into  v_pri_nombre, v_seg_nombre,v_apellido,v_fec_nacimiento, v_est_civil,v_cod_sexo
                  from ba_per_fisicas a
                   where a.cod_persona= v_cod_persona;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  v_pri_nombre:=null;
                  v_seg_nombre:=null;
                  v_apellido:=null;
                WHEN OTHERS THEN
                  v_pri_nombre:=null;
                  v_seg_nombre:=null;
                  v_apellido:=null;
              END;
                    --**** Para Estado Civil
                      --Valores Posibles
                    /*
                    SINGLE: Indicator marital status bachelor.
                    MARRIED: Indicator marital status married.
                    DIVORCED: Indicator marital status divorced.
                    COHABITANT: Indicator marital status cohabitant.
                    SEPERATED: Indicator of persons legally married, but no longer living with their spouse and has not obtained a divorce.
                    WIDOWED: Indicator of someone who has lost her spouse to death and hasn't remarried.
                    MARRIED_WITH_SEPARATED_PROPERTY: Indicator marital status married with separated property.
                    MARRIED_WITHOUT_SEPARATED_PROPERTY: Indicator marital status married without separated property.
                    CIVIL_UNION_AGREEMENT_WITH_SEPARATED_PROPERTY: Indicator marital status "union" with separated property through the civil agreement.
                    CIVIL_UNION_AGREEMENT_WITHOUT_SEPARATED_PROPERTY: Indicator marital status "union" without separated property through the civil agreement.
                    MARRIED_WITH_COMMUNITY_PROPERTY: Indicator marital status married with community property.
                    NO_INFO: Without information registered in systems.
                    ---Equivalencias con el CORE
                    Soltero/a                          S-->SINGLE
                    Casado/a sin separacion de bienes  C-->MARRIED_WITHOUT_SEPARATED_PROPERTY
                    Viudo/a                            V-->WIDOWED
                    Divorciado/a                      D-->DIVORCED
                    Casado/a con separación de Bienes  B-->MARRIED_WITH_SEPARATED_PROPERTY
                    Union de Hecho                    U-->COHABITANT
                    Separado/a                        E-->SEPERATED
                    Otros                              O-->NO_INFO
                    */
                    v_id_est_civil:= case v_est_civil
                                        when 'S' then 'SINGLE'
                                        when 'C' then 'MARRIED_WITHOUT_SEPARATED_PROPERTY'
                                        when 'V' then 'WIDOWED'
                                        when 'D' then 'DIVORCED'
                                        when 'B' then 'MARRIED_WITH_SEPARATED_PROPERTY'
                                        when 'U' then 'COHABITANT'
                                        when 'E' then 'SEPERATED'
                                        when 'O' then 'NO_INFO'
                                        else null
                                      END;

                    v_det_est_civil:= case v_id_est_civil
                                        when 'SINGLE' then 'Soltero/a'
                                        when 'MARRIED_WITHOUT_SEPARATED_PROPERTY'  then 'Casado/a sin separacion de bienes'
                                        when 'WIDOWED' then 'Viudo/a'
                                        when 'DIVORCED' then 'Divorciado/a'
                                        when 'MARRIED_WITH_SEPARATED_PROPERTY' then 'Casado/a con separación de Bienes'
                                        when 'COHABITANT' then 'Union de Hecho'
                                        when 'SEPERATED' then 'Separado/a'
                                        when 'NO_INFO' then 'Otros  '
                                        else null
                                      END;
                    /*Valores Posibles
                      MALE: Male.
                      FEMALE: Female.
                      *** Equivalencias con el CORE
                      M - Masculino  -> MALE
                      F-  Femenino   -> FEMALE

                      */
                   v_cod_sexo:= case v_cod_sexo
                              when 'M' then 'MALE'
                              when 'F' then 'FEMALE'
                              else null
                            end;
                    v_des_sexo:= case v_cod_sexo
                              when 'MALE' then 'Masculino'
                              when 'FEMALE' then 'Femenino'
                              else null
                            end;

      elsif v_tipo='J' then
            --Es persona juridica, ya tenemos primer nombre, lo demas nada
            v_pri_nombre:=null;
            v_seg_nombre:=null;
            v_apellido:=null;
            BEGIN
                  select a.fec_apertura,a.raz_social
                   into  v_fec_nacimiento,v_pri_nombre
                    from ba_per_juridicas a
                     where a.cod_persona= v_cod_persona;
                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                    v_pri_nombre:=null;
                    v_fec_nacimiento:=null;
                    v_apellido:=null;
                  WHEN OTHERS THEN
                    v_pri_nombre:=null;
                    v_fec_nacimiento:=null;
                    v_apellido:=null;
                END;
        end if;
        --**** Para tipo de Documento
        --Valores Posibles
        /*
        PASSPORT: Identifier document passport.
        NIF: Identifier document fiscal identification number.
        RESIDENTIAL_PASS: Identifier document residence.
        DNI: Identifier national identity document.
        RUC: Identifier document single tax registration.
        NIT: Identifier document tax identification number.
        CURP: Unique Population Registry Code.
        INE: National Electoral Institute Code.
        DL: Drivers License Number.
        STATE_ID: State Issued Identification.
        DIPLOMATIC: Identifier document issued to members of diplomatic missions residing in.
        FOREIGNERS: Identifier card for foreign residents.
        MILITARY: Identifier document that accredits the military situation.
        POLICE: Police Identification Card Identifier.
        RUT: Identifier national identity document.
        ---Equivalencias con el CORE
        1  CEDULA DE IDENTIDAD PARAGUAYA  CI      --> DNI
        2  PASAPORTE  PAS                         -->PASSPORT
        3  CERTIFICADO RESIDENCIA PERMANENTE  CRP -->RESIDENTIAL_PASS
        5  CEDULA DE IDENTIDAD EXTRANJERA  CRC   --> FOREIGNERS
        6  REGISTRO UNICO DEL CONTRIBUYENTE  RUC --> RUC
        10  SIN DOCUMENTO  SIN
        38  DUPLICADO 1  DUP                     --> DNI
        39  DUPLICADO 2  DUP                     --> DNI
        40  DUPLICADO 3  DUP                     --> DNI
        41  OTROS  OTR
        42  SWIFT  PJ
        43  DOCUMENTO NACIONAL DE IDENTIDAD  DNI --> DNI
        */
        v_tip_documento:= case v_cod_tip_documento
                            when 1 then 'DNI'
                            when 2 then 'PASSPORT'
                            when 3 then 'RESIDENTIAL_PASS'
                            when 5 then 'FOREIGNERS'
                            when 6 then 'RUC'
                            when 38 then 'DNI'
                            when 39 then 'DNI'
                            when 40 then 'DNI'
                            when 43 then 'DNI'
                            else null
                          END;

        v_des_documento:= case v_tip_documento
                            when 'DNI' then 'Documento Nacional de Identidad'
                            when 'PASSPORT'  then 'Pasaporte'
                            when 'RESIDENTIAL_PASS' then 'Certificado Residencia Permanente'
                            when 'FOREIGNERS' then 'Cedula de identidad Extranjera        '
                            when 'RUC' then 'Registro Unico de Contribuyente'
                            else null
                          END;
        --Para isClient
       -- Si el cliente ='S'
       -- Si es persona ='N'
       -- Sino Existe = null
       v_est_cliente:= case fug_es_cliente(v_cod_persona)
                         when 'N' then 'N'
                         when 'S' then 'S'
                         end ;
         if v_est_cliente='N' and  v_es_persona='S'  then
           --Ya no es Cliente, es sólo persona
           v_es_cliente:='N';
         elsif  v_est_cliente='N' and  v_es_persona='N'  then
           v_es_cliente:=null;
         end if;
       --Fecha de Nacimiento/Apertura "2016-09-02"
       v_fec_formateado:= to_char(v_fec_nacimiento,'yyyy-mm-dd');
   end if;
   --Si es persona Juridica y tiene cod_persona(Existe), enviamos espacio en blanco en vez de null
   if v_apellido is null and v_tipo='J' and v_cod_persona is not null then
     v_apellido:= ' ';
   end if;
   -- ******Cargamos salida
   v_retorno.customerId           :=v_cod_persona;
   v_retorno.firstName            :=v_pri_nombre;
   v_retorno.middleName           :=v_seg_nombre;
   v_retorno.lastName             :=v_apellido;
   v_retorno.suffix               :=null;
   v_retorno.birthDataCity        :=null;
   v_retorno.birthDataStateid     :=null;
   v_retorno.birthDataStatename   :=null;
   v_retorno.birthDataCountryid   :=null;
   v_retorno.birthDataCountryname :=null;
   v_retorno.birthDataBirthDate   :=v_fec_formateado;
   v_retorno.nationalityid        :=null;
   v_retorno.nationalityName      :=null;
   v_retorno.iDdocumentTypeid     :=v_tip_documento;
   v_retorno.iDdocumentTypeName   :=v_des_documento;
   v_retorno.iDcountryid          :=v_cod_pais;
   v_retorno.iDcountryname        :=null;
   v_retorno.iDstateid            :=null;
   v_retorno.iDstatename          :=null;
   v_retorno.iDstatusid           :=null;
   v_retorno.iDstatusname         :=null;
   v_retorno.iDissueDate          :=null;
   v_retorno.iDexpirationDate     :=null;
   v_retorno.iDdocumentNumber     :=v_nro_documeto;
   v_retorno.membershipDate       :=v_fec_membresia;
   v_retorno.lastAccessDate       :=null;
   v_retorno.personalTitleid      :=null;
   v_retorno.personalTitlename    :=null;
   v_retorno.maritalStatusid      :=v_id_est_civil;
   v_retorno.maritalStatusname    :=v_det_est_civil;
   v_retorno.genderid             :=v_cod_sexo;
   v_retorno.gendername           :=v_des_sexo;
   v_retorno.bankId               :=null;
   v_retorno.bankname             :=null;
   v_retorno.bankbranchId         :=nvl(v_cod_oficina,0); --Codigo de Oficina
   v_retorno.bankbranchname       :=v_oficina;    --Des. Oficina
   v_retorno.bankbranchcostCenter :=null;
   v_retorno.residencecountryid   :=null;
   v_retorno.residencecountryname :=null;
   v_retorno.residenceTypeid      :=null;
   v_retorno.residenceTypename    :=null;
   v_retorno.residencestartDate   :=null;
   v_retorno.pEPid                :=null;
   v_retorno.pEPfullName          :=null;
   v_retorno.pEPposition          :=null;
   v_retorno.socialSecurityNumber :=null;
   v_retorno.isClient             :=v_es_cliente;
     paw_uti.pr_mensajeusuario('OP_APROBADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);
  return v_retorno;
END;

FUNCTION fu_obt_customersid(
  p_cod_persona IN VARCHAR2 default null
) RETURN typ_datCustomer IS
 v_retorno       TYP_DATCUSTOMER := TYP_DATCUSTOMER();
 v_tipo          varchar2(1);
 v_pri_nombre    ba_personas.nom_completo%type;
 v_seg_nombre    ba_per_fisicas.seg_nombre%type;
 v_apellido      varchar2(100);
 v_nro_documeto  ba_personas.nro_documento%type;
 v_cod_tip_documento ba_personas.cod_tip_documento%type;
 v_cod_persona   ba_personas.cod_persona%type;
 v_fec_nacimiento date;
 v_fec_formateado varchar(20);
 v_tip_documento varchar2(100);
 v_des_documento varchar2(100);
 v_est_civil     ba_per_fisicas.est_civil%type;
 v_id_est_civil  varchar2(100);
 v_det_est_civil varchar2(100);
 v_cod_sexo      varchar2(30);
 v_des_sexo      varchar2(100);
 v_est_cliente   varchar2(1);
 v_cod_oficina   varchar2(100);
 v_oficina       varchar2(100);
 v_es_cliente    varchar2(1):=null;
 v_es_persona   varchar2(1):=null;
 v_fec_membresia varchar(10);
 v_cod_pais number(3);
 v_cod_pais_iso      varchar2(10):=null;


 /*--Para p_cod_tip_documento :
    --Valores posibles
    CI  -> Cedula de Identidad
    RUC -> Ruc
    CRC -> Cédula de Identidad Extranjera
    PAS -> Pasaporte
    DNI -> Documento Nacional de Identidad
    CRP -> Cértificado de Residencia Permanente
    COD -> Codigo Interno
    --Para isClient
       - Si el cliente ='S'
       - Si es persona ='N'
       - Sino Existe = null*/
BEGIN

  --Validamos que ingrese un filtro para Buscar
  if p_cod_persona is null then
       paw_uti.pr_mensajeusuario('VAL_PENTRADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);
       RETURN v_retorno;
  end if;
  --Buscamos si es persona física o juridica y si existe
  v_tipo:='N' ;
  v_pri_nombre:=null;
  v_cod_persona:= null;
  v_seg_nombre:= null;
  v_apellido:= null;
  v_nro_documeto:= null;
  v_tip_documento:= null;
  v_des_documento:= null;
  v_est_civil:= null;
  v_id_est_civil:= null;
  v_det_est_civil:= null;
  v_cod_sexo:= null;
  v_des_sexo:= null;
  v_cod_sexo:= null;
  v_oficina:= null;
  v_est_cliente:=null;
  v_cod_oficina:=null;
  v_es_cliente:=null;
  v_es_persona:=null;

  BEGIN
    select a.tipo,a.cod_persona, a.cod_tip_documento,a.nro_documento, a.cod_pais
     into v_tipo, v_cod_persona, v_cod_tip_documento, v_nro_documeto, v_cod_pais
      from ba_personas a , ge_cta_clientes b
       where a.cod_persona= nvl(p_cod_persona,a.cod_persona)
         and a.cod_persona= b.cod_persona
         and a.tipo = 'F'
          and rownum=1;
          v_es_cliente:='S';
           v_es_persona:='S';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
         --Buscamos si es persona
      BEGIN
         select a.tipo,a.cod_persona, a.cod_tip_documento,a.nro_documento, a.cod_pais
            into v_tipo, v_cod_persona, v_cod_tip_documento, v_nro_documeto, v_cod_pais
               from ba_personas a
                   where a.cod_persona = nvl(p_cod_persona,a.cod_persona)
                     and a.tipo = 'F'
                     and rownum=1;
                        v_es_cliente:='N';
                         v_es_persona:='S';
      EXCEPTION
         when no_data_found then
            v_es_cliente:= null;
             v_es_persona:='N';
      END;
    WHEN OTHERS THEN
      v_tipo:='N' ;
  END;


  if v_es_cliente is not null and v_tipo='F' then --Se ajusta para envio de personas fisicas unicamente

  begin
      select to_char(FEC_INGRESO, 'YYYY-MM-DD')
        into v_fec_membresia
        from ge_clientes
       where COD_PERSONA = p_cod_persona;
    exception
         when others then
           v_tipo:='N' ;
         end;

        begin
         v_cod_oficina:= fug_obt_ofi_cliente(v_cod_persona);
        exception
         when others then
           v_cod_oficina:= NULL;
         end;
        IF v_cod_oficina IS NOT NULL THEN
           v_oficina:= fue_obt_des_oficina(v_cod_oficina);
        ELSE
           v_oficina:= NULL;
        END IF;

      if v_tipo='F' then
         --Es persona fisica
             BEGIN
                select a.pri_nombre,a.seg_nombre,trim(trim(a.pri_apellido)||' '||trim(a.seg_apellido)),a.fec_nacimiento,a.est_civil,a.cod_sexo
                 into  v_pri_nombre, v_seg_nombre,v_apellido,v_fec_nacimiento, v_est_civil,v_cod_sexo
                  from ba_per_fisicas a
                   where a.cod_persona= v_cod_persona;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  v_pri_nombre:=null;
                  v_seg_nombre:=null;
                  v_apellido:=null;
                WHEN OTHERS THEN
                  v_pri_nombre:=null;
                  v_seg_nombre:=null;
                  v_apellido:=null;
              END;
                    --**** Para Estado Civil
                      --Valores Posibles
                    /*
                    SINGLE: Indicator marital status bachelor.
                    MARRIED: Indicator marital status married.
                    DIVORCED: Indicator marital status divorced.
                    COHABITANT: Indicator marital status cohabitant.
                    SEPERATED: Indicator of persons legally married, but no longer living with their spouse and has not obtained a divorce.
                    WIDOWED: Indicator of someone who has lost her spouse to death and hasn't remarried.
                    MARRIED_WITH_SEPARATED_PROPERTY: Indicator marital status married with separated property.
                    MARRIED_WITHOUT_SEPARATED_PROPERTY: Indicator marital status married without separated property.
                    CIVIL_UNION_AGREEMENT_WITH_SEPARATED_PROPERTY: Indicator marital status "union" with separated property through the civil agreement.
                    CIVIL_UNION_AGREEMENT_WITHOUT_SEPARATED_PROPERTY: Indicator marital status "union" without separated property through the civil agreement.
                    MARRIED_WITH_COMMUNITY_PROPERTY: Indicator marital status married with community property.
                    NO_INFO: Without information registered in systems.
                    ---Equivalencias con el CORE
                    Soltero/a                          S-->SINGLE
                    Casado/a sin separacion de bienes  C-->MARRIED_WITHOUT_SEPARATED_PROPERTY
                    Viudo/a                            V-->WIDOWED
                    Divorciado/a                      D-->DIVORCED
                    Casado/a con separación de Bienes  B-->MARRIED_WITH_SEPARATED_PROPERTY
                    Union de Hecho                    U-->COHABITANT
                    Separado/a                        E-->SEPERATED
                    Otros                              O-->NO_INFO
                    */
                    v_id_est_civil:= case v_est_civil
                                        when 'S' then 'SINGLE'
                                        when 'C' then 'MARRIED_WITHOUT_SEPARATED_PROPERTY'
                                        when 'V' then 'WIDOWED'
                                        when 'D' then 'DIVORCED'
                                        when 'B' then 'MARRIED_WITH_SEPARATED_PROPERTY'
                                        when 'U' then 'COHABITANT'
                                        when 'E' then 'SEPERATED'
                                        when 'O' then 'NO_INFO'
                                        else null
                                      END;

                    v_det_est_civil:= case v_id_est_civil
                                        when 'SINGLE' then 'Soltero/a'
                                        when 'MARRIED_WITHOUT_SEPARATED_PROPERTY'  then 'Casado/a sin separacion de bienes'
                                        when 'WIDOWED' then 'Viudo/a'
                                        when 'DIVORCED' then 'Divorciado/a'
                                        when 'MARRIED_WITH_SEPARATED_PROPERTY' then 'Casado/a con separación de Bienes'
                                        when 'COHABITANT' then 'Union de Hecho'
                                        when 'SEPERATED' then 'Separado/a'
                                        when 'NO_INFO' then 'Otros  '
                                        else null
                                      END;
                    /*Valores Posibles
                      MALE: Male.
                      FEMALE: Female.
                      *** Equivalencias con el CORE
                      M - Masculino  -> MALE
                      F-  Femenino   -> FEMALE

                      */
                   v_cod_sexo:= case v_cod_sexo
                              when 'M' then 'MALE'
                              when 'F' then 'FEMALE'
                              else null
                            end;
                    v_des_sexo:= case v_cod_sexo
                              when 'MALE' then 'Masculino'
                              when 'FEMALE' then 'Femenino'
                              else null
                            end;
        end if;
        --**** Para tipo de Documento
        --Valores Posibles
        /*
        PASSPORT: Identifier document passport.
        NIF: Identifier document fiscal identification number.
        RESIDENTIAL_PASS: Identifier document residence.
        DNI: Identifier national identity document.
        RUC: Identifier document single tax registration.
        NIT: Identifier document tax identification number.
        CURP: Unique Population Registry Code.
        INE: National Electoral Institute Code.
        DL: Drivers License Number.
        STATE_ID: State Issued Identification.
        DIPLOMATIC: Identifier document issued to members of diplomatic missions residing in.
        FOREIGNERS: Identifier card for foreign residents.
        MILITARY: Identifier document that accredits the military situation.
        POLICE: Police Identification Card Identifier.
        RUT: Identifier national identity document.
        ---Equivalencias con el CORE
        1  CEDULA DE IDENTIDAD PARAGUAYA  CI      --> DNI
        2  PASAPORTE  PAS                         -->PASSPORT
        3  CERTIFICADO RESIDENCIA PERMANENTE  CRP -->RESIDENTIAL_PASS
        5  CEDULA DE IDENTIDAD EXTRANJERA  CRC   --> FOREIGNERS
        6  REGISTRO UNICO DEL CONTRIBUYENTE  RUC --> RUC
        10  SIN DOCUMENTO  SIN
        38  DUPLICADO 1  DUP                     --> DNI
        39  DUPLICADO 2  DUP                     --> DNI
        40  DUPLICADO 3  DUP                     --> DNI
        41  OTROS  OTR
        42  SWIFT  PJ
        43  DOCUMENTO NACIONAL DE IDENTIDAD  DNI --> DNI
        */
        v_tip_documento:= case v_cod_tip_documento
                            when 1 then 'DNI'
                            when 2 then 'PASSPORT'
                            when 3 then 'RESIDENTIAL_PASS'
                            when 5 then 'FOREIGNERS'
                            when 6 then 'RUC'
                            when 38 then 'DNI'
                            when 39 then 'DNI'
                            when 40 then 'DNI'
                            when 43 then 'DNI'
                            else null
                          END;

        v_des_documento:= case v_tip_documento
                            when 'DNI' then 'Documento Nacional de Identidad'
                            when 'PASSPORT'  then 'Pasaporte'
                            when 'RESIDENTIAL_PASS' then 'Certificado Residencia Permanente'
                            when 'FOREIGNERS' then 'Cedula de identidad Extranjera        '
                            when 'RUC' then 'Registro Unico de Contribuyente'
                            else null
                          END;
        --Para isClient
       -- Si el cliente ='S'
       -- Si es persona ='N'
       -- Sino Existe = null
       v_est_cliente:= case fug_es_cliente(v_cod_persona)
                         when 'N' then 'N'
                         when 'S' then 'S'
                         end ;
         if v_est_cliente='N' and  v_es_persona='S'  then
           --Ya no es Cliente, es sólo persona
           v_es_cliente:='N';
         elsif  v_est_cliente='N' and  v_es_persona='N'  then
           v_es_cliente:=null;
         end if;
       --Fecha de Nacimiento/Apertura "2016-09-02"
       v_fec_formateado:= to_char(v_fec_nacimiento,'yyyy-mm-dd');

           --Para retornar cod_pais de tipo de documento
          v_cod_pais_iso := null;
          BEGIN
              select b.cod_pai_iso
                into v_cod_pais_iso
                 from  ba_personas a, ba_paises b
                    where a.cod_pai_documento=b.cod_pais
                       and a.cod_persona= v_cod_persona
                       and a.tipo = 'F'
                       and rownum=1;
           EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                    v_cod_pais_iso := null;
                   WHEN OTHERS THEN
                    v_cod_pais_iso := null;
           END;
   end if;

   -- ******Cargamos salida
   v_retorno.customerId           :=v_cod_persona;
   v_retorno.firstName            :=v_pri_nombre;
   v_retorno.middleName           :=v_seg_nombre;
   v_retorno.lastName             :=v_apellido;
   v_retorno.suffix               :=null;
   v_retorno.birthDataCity        :=null;
   v_retorno.birthDataStateid     :=null;
   v_retorno.birthDataStatename   :=null;
   v_retorno.birthDataCountryid   :=null;
   v_retorno.birthDataCountryname :=null;
   v_retorno.birthDataBirthDate   :=v_fec_formateado;
   v_retorno.nationalityid        :=null;
   v_retorno.nationalityName      :=null;
   v_retorno.iDdocumentTypeid     :=v_tip_documento;
   v_retorno.iDdocumentTypeName   :=v_des_documento;
   v_retorno.iDcountryid          :=v_cod_pais_iso;
   v_retorno.iDcountryname        :=null;
   v_retorno.iDstateid            :=null;
   v_retorno.iDstatename          :=null;
   v_retorno.iDstatusid           :=null;
   v_retorno.iDstatusname         :=null;
   v_retorno.iDissueDate          :=null;
   v_retorno.iDexpirationDate     :=null;
   v_retorno.iDdocumentNumber     :=v_nro_documeto;
   v_retorno.membershipDate       :=v_fec_membresia;
   v_retorno.lastAccessDate       :=null;
   v_retorno.personalTitleid      :=null;
   v_retorno.personalTitlename    :=null;
   v_retorno.maritalStatusid      :=v_id_est_civil;
   v_retorno.maritalStatusname    :=v_det_est_civil;
   v_retorno.genderid             :=v_cod_sexo;
   v_retorno.gendername           :=v_des_sexo;
   v_retorno.bankId               :=null;
   v_retorno.bankname             :=null;
   v_retorno.bankbranchId         :=nvl(v_cod_oficina,0); --Codigo de Oficina
   v_retorno.bankbranchname       :=v_oficina;    --Des. Oficina
   v_retorno.bankbranchcostCenter :=null;
   v_retorno.residencecountryid   :=null;
   v_retorno.residencecountryname :=null;
   v_retorno.residenceTypeid      :=null;
   v_retorno.residenceTypename    :=null;
   v_retorno.residencestartDate   :=null;
   v_retorno.pEPid                :=null;
   v_retorno.pEPfullName          :=null;
   v_retorno.pEPposition          :=null;
   v_retorno.socialSecurityNumber :=null;
   v_retorno.isClient             :=v_es_cliente;
     paw_uti.pr_mensajeusuario('OP_APROBADA', v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);
  return v_retorno;
END;


  FUNCTION fu_obt_cus_contact_info(
                              p_cod_persona IN VARCHAR2 default null
           ) RETURN TYP_CUSTOMER_CONTACT IS
      v_retorno       TYP_CUSTOMER_CONTACT := TYP_CUSTOMER_CONTACT();
      v_lis_contactos TYP_LIST_CUSTOMER_CONTACT_INFO := TYP_LIST_CUSTOMER_CONTACT_INFO();
      v_cod_persona   ba_personas.cod_persona%type;
      v_cust_info     typ_datCustomer;
      v_ema_ba_persona ba_personas.dir_correo%type;
      v_con_ema_ba_persona TYP_CUSTOMER_CONTACT_INFO;
      v_tie_ema_principal NUMERIC := 0;

      CURSOR mails(p_cod_per IN  ba_personas.cod_persona%type ) IS
          select * from ba_mails m
          where m.cod_persona = p_cod_per;

      CURSOR telefonos(p_cod_per IN  ba_personas.cod_persona%type ,
                       p_tipo IN varchar2 DEFAULT NULL) IS
          select * from ba_telefonos t
          where t.cod_persona = p_cod_per
              AND ((p_tipo is null ) OR (t.TIP_linea = p_tipo));

      TIPO_EMAIL     CONSTANT VARCHAR2(7) := 'EMAIL';
      TIPO_CELULAR     CONSTANT VARCHAR2(7) := 'CELULAR';
      TIPO_TELEFONO   CONSTANT VARCHAR2(8) := 'TELEFONO';

  BEGIN
      --inicializamos con 'ok'
      paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      v_cust_info := fu_obt_customerid(p_cod_persona);

      IF v_cust_info.error = 'S' THEN
         v_retorno.error                := v_cust_info.error;
         v_retorno.nombreRespuesta      := v_cust_info.nombreRespuesta;
         v_retorno.descripcionRespuesta := v_cust_info.descripcionRespuesta;
      END IF;

      IF v_retorno.error <> 'S' THEN
         --aqui ya validamos que la persona exista
         v_cod_persona := v_cust_info.customerId;

         --init data
         v_retorno.cantContactos :=0;
         v_retorno.tieneEmail := 'N';
         v_retorno.tieneCelular := 'N';
         v_retorno.tieneTelefono :='N';

         --primero vamos a email

         FOR em IN mails(v_cod_persona) LOOP
             DECLARE
                 v_contacto      TYP_CUSTOMER_CONTACT_INFO := TYP_CUSTOMER_CONTACT_INFO;
             BEGIN
                 v_contacto.tipoContacto := TIPO_EMAIL;
                 v_contacto.contacto := em.dir_correo;
                 v_contacto.principal := em.principal;
                 v_contacto.ultimaActualizacion := em.fec_modificacion;

                 if em.principal = 'S' then
                     v_tie_ema_principal := 1;
                 end if;

                 v_lis_contactos.Extend;
                 v_lis_contactos(v_lis_contactos.count) := v_contacto;
                 v_retorno.tieneEmail := 'S';
             END;
         END LOOP;

         --agregamos el mail que se encuentra registrado en BA_PERSONAS
         SELECT DIR_CORREO
         INTO v_ema_ba_persona
         from BA_PERSONAS
         where cod_persona = v_cod_persona;

         IF  v_ema_ba_persona is not null then
             v_con_ema_ba_persona := TYP_CUSTOMER_CONTACT_INFO;
             v_con_ema_ba_persona.tipoContacto := TIPO_EMAIL;
             v_con_ema_ba_persona.contacto := v_ema_ba_persona;

             IF v_tie_ema_principal = 0 then
                 v_con_ema_ba_persona.principal := 'S';
             else
                 v_con_ema_ba_persona.principal := 'N';
             end if;

             v_lis_contactos.Extend;
             v_lis_contactos(v_lis_contactos.count) := v_con_ema_ba_persona;
             v_retorno.tieneEmail := 'S';

         END IF;

         --CELULAR
         FOR cel IN telefonos(v_cod_persona, 'C') LOOP
             DECLARE
                 v_contacto      TYP_CUSTOMER_CONTACT_INFO := TYP_CUSTOMER_CONTACT_INFO;
             BEGIN
                 v_contacto.tipoContacto := TIPO_CELULAR;
                 v_contacto.contacto := cel.area || cel.telefono;
                 v_contacto.principal := cel.principal;
                 v_contacto.ultimaActualizacion := cel.fec_modificacion;

                 v_lis_contactos.Extend;
                 v_lis_contactos(v_lis_contactos.count) := v_contacto;
                 v_retorno.tieneCelular := 'S';
             END;
         END LOOP;

         --TELEFONO
         FOR tel IN telefonos(v_cod_persona, 'B') LOOP
             DECLARE
                 v_contacto      TYP_CUSTOMER_CONTACT_INFO := TYP_CUSTOMER_CONTACT_INFO;
             BEGIN
                 v_contacto.tipoContacto := TIPO_TELEFONO;
                 v_contacto.contacto := tel.area || tel.telefono;
                 v_contacto.codigoRegional := tel.area;
                 v_contacto.principal := tel.principal;
                 v_contacto.ultimaActualizacion := tel.fec_modificacion;

                 v_lis_contactos.Extend;
                 v_lis_contactos(v_lis_contactos.count) := v_contacto;
                 v_retorno.tieneTelefono :='S';
             END;
         END LOOP;

         v_retorno.listaContactos := v_lis_contactos;
         v_retorno.cantContactos := v_lis_contactos.count;

      END IF;

      RETURN v_retorno;
  EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
  END fu_obt_cus_contact_info;


FUNCTION fu_obt_businessid(p_cod_persona IN VARCHAR2)
  RETURN typ_datBusiness IS
  v_ret TYP_DATBUSINESS := TYP_DATBUSINESS();

BEGIN

  v_ret.businessId := p_cod_persona;

  BEGIN

    select pe.COD_TIP_DOCUMENTO,
           (select batido.ABREVIATURA
              from BA_TIP_DOCUMENTOS batido
             where batido.COD_TIP_DOCUMENTO = pe.COD_TIP_DOCUMENTO),
           pe.NRO_DOCUMENTO,
           pe.COD_RUB_PRIMARIO,
           (select to_char(gecli.FEC_INGRESO, 'YYYYMMDD')
              from ge_clientes gecli
             where gecli.COD_PERSONA = pe.cod_persona),
           (select gerub.descripcion
              from GE_RUB_ECONOMICOS gerub
             where gerub.COD_RUB_ECONOMICO = pe.COD_RUB_PRIMARIO),
             pe.cod_pais
      into v_ret.businessDocumentTypeId,
           v_ret.businessDocumentType,
           v_ret.businessDocumentNumber,
           v_ret.economicActivityId,
           v_ret.membershipDate,
           v_ret.economicActivity,
           v_ret.businessCountryId
      from BA_PERSONAS pe
     where pe.tipo = 'J'
       and COD_PERSONA = p_cod_persona;

    select RAZ_SOCIAL, NOM_COMERCIAL, to_char(FEC_APERTURA, 'YYYYMMDD')
      into v_ret.businessName, v_ret.doingBusinessAs, v_ret.formationDate
      from BA_PER_JURIDICAS
     where cod_persona = p_cod_persona;

  EXCEPTION
     WHEN OTHERS THEN
          paw_uti.pr_mensajeusuario('VAL_PENTRADA',
                            v_ret.nombrerespuesta,
                            v_ret.descripcionrespuesta,
                            v_ret.error);
        RETURN v_ret;
  END;

  paw_uti.pr_mensajeusuario('OP_APROBADA',
                            v_ret.nombrerespuesta,
                            v_ret.descripcionrespuesta,
                            v_ret.error);
  return v_ret;
END;

FUNCTION fu_obt_businessesid(p_cod_persona IN VARCHAR2)
  RETURN typ_datBusiness IS

  v_ret TYP_DATBUSINESS := TYP_DATBUSINESS();

   v_businessId              VARCHAR2(10) := null;  -- cod persona
   v_businessName            VARCHAR2(120):= null; -- razon social
   v_doingBusinessAs         VARCHAR2(65) := null; -- nombre comercial/fantasia
   v_formationDate           varchar2(8) := null;   -- fecha de apertura de la empresa
   v_businessDocumentTypeId  VARCHAR2(3):= null;   -- codigo de tipo de documento
   v_businessDocumentType    VARCHAR2(4):= null;  -- codigo de tipo de documento
   v_businessDocumentNumber  VARCHAR2(20):= null;  -- nro de documento
   v_businessCountryId       VARCHAR2(3):= null;   -- codigo del pais de la empresa
   v_membershipDate          varchar2(8):= null;   -- fecha de membresia en la entidad
   v_economicActivityId      VARCHAR2(6):= null;   -- codigo de rubro primario
   v_economicActivity        VARCHAR2(60):= null;   -- codigo de rubro primario
   v_error                   VARCHAR2(1):= 'N';   -- Indica si la respuesta es de error o no
   v_nombreRespuesta         VARCHAR2(15):= null;  -- Codigo de respuesta
   v_descripcionRespuesta    VARCHAR2(200):= null;

BEGIN
  BEGIN

    select pe.cod_persona, pe.COD_TIP_DOCUMENTO,
           (select batido.ABREVIATURA
              from BA_TIP_DOCUMENTOS batido
             where batido.COD_TIP_DOCUMENTO = pe.COD_TIP_DOCUMENTO),
           pe.NRO_DOCUMENTO,
           pe.COD_RUB_PRIMARIO,
           (select to_char(gecli.FEC_INGRESO, 'YYYYMMDD')
              from ge_clientes gecli
             where gecli.COD_PERSONA = pe.cod_persona),
           (select gerub.descripcion
              from GE_RUB_ECONOMICOS gerub
             where gerub.COD_RUB_ECONOMICO = pe.COD_RUB_PRIMARIO),
             pe.cod_pais
      into v_businessId,
          v_businessDocumentTypeId,
           v_businessDocumentType,
           v_businessDocumentNumber,
           v_economicActivityId,
           v_membershipDate,
           v_economicActivity,
           v_businessCountryId
      from BA_PERSONAS pe
     where pe.tipo = 'J'
       and COD_PERSONA = p_cod_persona;

    select RAZ_SOCIAL, NOM_COMERCIAL, to_char(FEC_APERTURA, 'YYYYMMDD')
      into v_businessName, v_doingBusinessAs, v_formationDate
      from BA_PER_JURIDICAS
     where cod_persona = p_cod_persona;

  EXCEPTION
      WHEN NO_DATA_FOUND THEN
      BEGIN
        v_error := 'N';
      END;

      WHEN OTHERS THEN
          v_error := 'S';
      END;

      v_ret.businessId := v_businessId;
      v_ret.businessName := v_businessName;
      v_ret.doingBusinessAs := v_doingBusinessAs;
      v_ret.formationDate := v_formationDate;
      v_ret.businessDocumentTypeId := v_businessDocumentTypeId;
      v_ret.businessDocumentType := v_businessDocumentType;
      v_ret.businessDocumentNumber := v_businessDocumentNumber;
      v_ret.businessCountryId := v_businessCountryId;
      v_ret.membershipDate := v_membershipDate;
      v_ret.economicActivityId := v_economicActivityId;
      v_ret.economicActivity := v_economicActivity;
      v_ret.error := v_error;
      v_ret.nombreRespuesta := v_nombreRespuesta;
      v_ret.descripcionRespuesta := v_descripcionRespuesta;

      RETURN v_ret;
END;


FUNCTION fu_obt_businesses(p_cod_persona   IN VARCHAR2 DEFAULT NULL,
                           p_tip_documento IN VARCHAR2 DEFAULT NULL,
                           p_nro_documento IN VARCHAR2 DEFAULT NULL,
                           p_rows          IN VARCHAR2 DEFAULT NULL) RETURN typ_datBusiness IS
   v_ret TYP_DATBUSINESS := TYP_DATBUSINESS();

   v_businessId             VARCHAR2(10) := NULL; -- cod persona
   v_businessName           VARCHAR2(120) := NULL; -- razon social
   v_doingBusinessAs        VARCHAR2(65) := NULL; -- nombre comercial/fantasia
   v_formationDate          VARCHAR2(8) := NULL; -- fecha de apertura de la empresa
   v_businessDocumentTypeId VARCHAR2(3) := NULL; -- codigo de tipo de documento
   v_businessDocumentType   VARCHAR2(4) := NULL; -- codigo de tipo de documento
   v_businessDocumentNumber VARCHAR2(20) := NULL; -- nro de documento
   v_businessCountryId      VARCHAR2(3) := NULL; -- codigo del pais de la empresa
   v_membershipDate         VARCHAR2(8) := NULL; -- fecha de membresia en la entidad
   v_economicActivityId     VARCHAR2(6) := NULL; -- codigo de rubro primario
   v_economicActivity       VARCHAR2(60) := NULL; -- codigo de rubro primario
   v_error                  VARCHAR2(1) := 'N'; -- Indica si la respuesta es de error o no
   v_nombreRespuesta        VARCHAR2(15) := NULL; -- Codigo de respuesta
   v_descripcionRespuesta   VARCHAR2(200) := NULL;
   v_cod_oficina            varchar2(100):=null;
   v_oficina                varchar2(100):=null;

BEGIN
   BEGIN
      SELECT pe.cod_persona, pe.COD_TIP_DOCUMENTO, pe.nom_completo,
             (SELECT batido.ABREVIATURA
                 FROM BA_TIP_DOCUMENTOS batido
                WHERE batido.COD_TIP_DOCUMENTO = pe.COD_TIP_DOCUMENTO), pe.NRO_DOCUMENTO, pe.COD_RUB_PRIMARIO,
             (SELECT to_char(gecli.FEC_INGRESO, 'YYYYMMDD')
                 FROM ge_clientes gecli
                WHERE gecli.COD_PERSONA = pe.cod_persona),
             (SELECT gerub.descripcion
                 FROM GE_RUB_ECONOMICOS gerub
                WHERE gerub.COD_RUB_ECONOMICO = pe.COD_RUB_PRIMARIO), pe.cod_pais
        into v_businessId,
          v_businessDocumentTypeId,
          v_businessName,
           v_businessDocumentType,
           v_businessDocumentNumber,
           v_economicActivityId,
           v_membershipDate,
           v_economicActivity,
           v_businessCountryId
        FROM BA_PERSONAS pe, ba_tip_documentos td
       WHERE pe.cod_tip_documento = td.cod_tip_documento
             AND pe.tipo = 'J'
             AND COD_PERSONA = NVL(p_cod_persona,COD_PERSONA) 
             and td.abreviatura = NVL(p_tip_documento,td.abreviatura)
             AND pe.nro_documento = nvl(p_nro_documento,pe.nro_documento)
             AND (rownum <= p_rows OR p_rows IS NULL);

      SELECT RAZ_SOCIAL, NOM_COMERCIAL, to_char(FEC_APERTURA, 'YYYYMMDD')
        INTO v_ret.businessName, v_ret.doingBusinessAs, v_ret.formationDate
        FROM BA_PER_JURIDICAS
       WHERE (COD_PERSONA = v_businessId);

   EXCEPTION
   WHEN NO_DATA_FOUND THEN
      BEGIN
        v_error := 'N';
      END;

      WHEN OTHERS THEN
          --raise_application_error(-20000, 'error:'||SQLERRM); 
          v_error := 'S';
      END;
      
   BEGIN
      v_cod_oficina := fug_obt_ofi_cliente(v_businessId);
   EXCEPTION
      WHEN OTHERS THEN
         v_cod_oficina := NULL;
   END;
   
   IF v_cod_oficina IS NOT NULL THEN
      v_oficina := fue_obt_des_oficina(v_cod_oficina);
   ELSE
      v_oficina := NULL;
   END IF;

      v_ret.businessId := v_businessId;
      v_ret.businessName := v_businessName;
      v_ret.doingBusinessAs := v_doingBusinessAs;
      v_ret.formationDate := v_formationDate;
      v_ret.businessDocumentTypeId := v_businessDocumentType/*v_businessDocumentTypeId*/;
      v_ret.businessDocumentType := v_businessDocumentType;
      v_ret.businessDocumentNumber := v_businessDocumentNumber;
      v_ret.businessCountryId := v_businessCountryId;
      v_ret.membershipDate := v_membershipDate;
      v_ret.economicActivityId := v_economicActivityId;
      v_ret.economicActivity := v_economicActivity;
      --
      v_ret.bankId               :=null;
      v_ret.bankname             :=null;
      v_ret.bankbranchId         :=nvl(v_cod_oficina,0); --Codigo de Oficina
      v_ret.bankbranchname       :=v_oficina;    --Des. Oficina
      --    
      v_ret.error := v_error;
      v_ret.nombreRespuesta := v_nombreRespuesta;
      v_ret.descripcionRespuesta := v_descripcionRespuesta;
      
      RETURN v_ret;
END;

--------------------------------------------------------------------------------------------

FUNCTION fu_obt_gru_economicos(p_nro_doc     IN VARCHAR2,
                               p_cod_tip_doc IN VARCHAR2)
  RETURN TYP_GRUP_ECONOMICO IS

  vret TYP_GRUP_ECONOMICO := TYP_GRUP_ECONOMICO();

BEGIN

  vret.participantes := TYP_LIST_GRUP_ECON_PARTICIPANT();

  BEGIN

    select c.COD_GRU_ECONOMICO, g.descripcion
      into vret.codGrupo, vret.nombreGrupo
      from ge_clientes c
      join BA_PERSONAS p
        on c.COD_PERSONA = p.COD_PERSONA
      join ge_gru_economicos g
        on g.cod_gru_economico = c.cod_gru_economico
     where p.NRO_DOCUMENTO = p_nro_doc
       and p.COD_TIP_DOCUMENTO = p_cod_tip_doc;

    for j in (select p.COD_TIP_DOCUMENTO as codTipDoc,
           (select t.ABREVIATURA
              from BA_TIP_DOCUMENTOS t
             where t.COD_TIP_DOCUMENTO = p.cod_tip_documento) as nomTipDoc,
           p.NRO_DOCUMENTO as nroDoc,
           p.COD_PERSONA as codPers
      from BA_PERSONAS p
      join GE_CLIENTES c
        on c.COD_PERSONA = p.COD_PERSONA
     where c.COD_GRU_ECONOMICO = vret.codGrupo)
     loop
       vret.participantes.extend;
       vret.participantes(vret.participantes.count) := TYP_DAT_GRUP_ECON_PARTICIPANT(j.codtipdoc, j.nomtipdoc, j.nroDoc, j.codPers);
     end loop;

  EXCEPTION

    WHEN OTHERS THEN
     paw_uti.pr_mensajeusuario('VAL_PENTRADA',
                            vret.nombrerespuesta,
                            vret.descripcionrespuesta,
                            vret.error);
      RETURN vret;
  END;

  paw_uti.pr_mensajeusuario('OP_APROBADA',
                            vret.nombrerespuesta,
                            vret.descripcionrespuesta,
                            vret.error);
  return vret;
END;

--------------------------------------------------------------------------------------------


FUNCTION fu_obt_niveles_riesgo(p_nro_doc     IN VARCHAR2,
                               p_cod_tip_doc IN VARCHAR2)
  RETURN TYP_NIVELES_RIESGO IS

  vret TYP_NIVELES_RIESGO := TYP_NIVELES_RIESGO();

BEGIN

  BEGIN

    select cli.CAT_RIESGO, cli.CAT_SISTEMA, cli.cod_persona
      into vret.riesgoEntidad, vret.riesgoSistema, vret.codPersona
      from ge_clientes cli
      join BA_PERSONAS pers
        on pers.COD_PERSONA = cli.COD_PERSONA
     where pers.COD_TIP_DOCUMENTO = p_cod_tip_doc
       and pers.NRO_DOCUMENTO = p_nro_doc
       and rownum = 1;

  EXCEPTION

    WHEN OTHERS THEN
      paw_uti.pr_mensajeusuario('VAL_PENTRADA',
                            vret.nombrerespuesta,
                            vret.descripcionrespuesta,
                            vret.error);
      RETURN vret;
  END;

  paw_uti.pr_mensajeusuario('OP_APROBADA',
                            vret.nombrerespuesta,
                            vret.descripcionrespuesta,
                            vret.error);
  return vret;
END;

-- ---------------------------------------------------------------------------------
FUNCTION fu_obt_addresses(codPersona IN VARCHAR2)
  RETURN TYP_DATADDRESSES IS
  v_ret TYP_DATADDRESSES := TYP_DATADDRESSES();

BEGIN

  v_ret.codPersona := codPersona;

  BEGIN

    select di.COD_PERSONA || di.COD_DIRECCION as idDir,
           di.direccion || ' ' || nvl(di.NUMERO, '') || ' ' ||
           nvl(di.DIR_LATERAL, '') || ' ' || nvl(di.EDIFICIO, '') || ' ' ||
           nvl(di.PISO, '') || ' ' || nvl(di.DEPARTAMENTO, '') as dir,
           ci.DESCRIPCION as ciudad,
           de.COD_DEPARTAMENTO as iddpto,
            de.DESCRIPCION as dpto,
            pa.COD_PAIS as idPais,
            pa.DESCRIPCION as nomPais,
           di.TIPO as idtipDir,
           nvl((select tip.SIGNIFICADO from BA_COD_REFERENCIAS tip where tip.DOMINIO like '%TIP_DIRECCION%' and tip.VAL_MINIMO = di.TIPO and ROWNUM < 2), '') as tipDir,
           pe.tipo
    into v_ret.idDireccion, v_ret.direccion, v_Ret.ciudad, v_ret.idDpto,v_ret.nombreDpto, v_ret.idPais, v_ret.nombrePais, v_ret.idTipoDireccion, v_ret.nombreTipoDireccion, v_ret.tipoPersona
    from BA_DIRECCIONES di
    join BA_CIUDADES ci on ci.COD_CIUDAD = di.COD_CIUDAD and ci.COD_PAIS = di.COD_PAIS
     join BA_DEPARTAMENTOS de on de.COD_DEPARTAMENTO = ci.COD_DEPARTAMENTO
     join BA_PAISES pa on pa.COD_PAIS = di.COD_PAIS
     join ba_personas pe on pe.cod_persona = di.cod_persona
    where di.COD_PERSONA = codPersona
      and di.principal = 'S';

  EXCEPTION
      WHEN OTHERS THEN
        paw_uti.pr_mensajeusuario('VAL_PENTRADA',
                            v_ret.nombrerespuesta,
                            v_ret.descripcionrespuesta,
                            v_ret.error);
        RETURN v_ret;
  END;

    paw_uti.pr_mensajeusuario('OP_APROBADA',
                              v_ret.nombrerespuesta,
                              v_ret.descripcionrespuesta,
                              v_ret.error);
  return v_ret;
END;

-- ---------------------------------------------------------------------------------
FUNCTION fu_obt_actividad_econ(codPersona IN VARCHAR2)
  RETURN TYP_DATECONOMICDATA IS
  v_ret TYP_DATECONOMICDATA := TYP_DATECONOMICDATA();

BEGIN

  BEGIN

  select re.COD_RUB_ECONOMICO, re.DESCRIPCION
  into v_ret.idActividadEco, v_ret.actividadEco
  from ba_personas pe
  join ge_rub_economicos re on re.cod_rub_economico = pe.cod_rub_primario
  where pe.cod_persona = codPersona and pe.tipo = 'F';

  EXCEPTION
      WHEN OTHERS THEN
        paw_uti.pr_mensajeusuario('VAL_PENTRADA',
                            v_ret.nombrerespuesta,
                            v_ret.descripcionrespuesta,
                            v_ret.error);
        RETURN v_ret;
  END;

  paw_uti.pr_mensajeusuario('OP_APROBADA',
                            v_ret.nombrerespuesta,
                            v_ret.descripcionrespuesta,
                            v_ret.error);
  return v_ret;
END;
-- ---------------------------------------------------------------------------------
FUNCTION fu_obt_oficial_cuenta(codPersona IN VARCHAR2)
  RETURN TYP_DATAGENT IS
  v_ret TYP_DATAGENT := TYP_DATAGENT();

BEGIN

  BEGIN

  select u.cod_usuario, u.nombre, u.dir_correo, pe.cod_persona, pe.tipo
  into v_ret.idAgent, v_ret.firstName, v_ret.email, v_ret.codPersona, v_ret.tipoPersona
  from ba_usuarios u
  join GE_CLIENTES g on g.COD_USU_OFICIAL = u.COD_USUARIO
  join ba_personas pe on pe.cod_persona = g.cod_persona
  where g.COD_PERSONA = codPersona;

  EXCEPTION
      WHEN OTHERS THEN
       paw_uti.pr_mensajeusuario('VAL_PENTRADA',
                            v_ret.nombrerespuesta,
                            v_ret.descripcionrespuesta,
                            v_ret.error);
        RETURN v_ret;
  END;

  paw_uti.pr_mensajeusuario('OP_APROBADA',
                            v_ret.nombrerespuesta,
                            v_ret.descripcionrespuesta,
                            v_ret.error);
  return v_ret;
END;

    FUNCTION fu_ins_dato_generico(p_tipo  IN BW_DAT_GENERICOS.tipo%TYPE,
                                  p_cod_persona  IN BW_DAT_GENERICOS.cod_persona%TYPE, 
                                  p_cod_empresa  IN BW_DAT_GENERICOS.cod_empresa%TYPE,
                                  p_descripcion  IN BW_DAT_GENERICOS.descripcion%TYPE,
                                  p_datos_genericos IN BW_DAT_GENERICOS.datos_genericos%TYPE,
                                  p_cod_canal  IN VARCHAR2, 
                                  p_cod_sesion IN VARCHAR2 DEFAULT NULL)
                                  RETURN TYP_MENSAJERESPUESTA IS
        v_retorno typ_mensajeRespuesta := typ_mensajeRespuesta();
    BEGIN
        PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_cod_sesion, ' ', p_cod_empresa, 
                                    'Insertando dato generico: ' || p_tipo || ' - ' || p_descripcion || ', ' || 
                                    PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null), 
                                    PAW_UTI.BITACORA_ENTRADA);
        BEGIN
            INSERT INTO BW_DAT_GENERICOS (cod_dato, tipo, cod_persona, cod_empresa, descripcion, datos_genericos) 
            VALUES (S_BW_DAT_GENERICOS.NEXTVAL, p_tipo, p_cod_persona, p_cod_empresa, p_descripcion, p_datos_genericos);
        EXCEPTION
            WHEN OTHERS THEN
                PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_cod_sesion, ' ', p_cod_empresa, 
                                            'Error al insertar dato generico: ' || p_tipo || ' - ' || p_descripcion || ', ' || SQLERRM, 
                                            PAW_UTI.BITACORA_ERROR);
        END;
      
        RETURN v_retorno;
    END;

-------------Obtener bancos para transferencias----------------------------------------------
   FUNCTION fu_obtenerBancos(p_tipo            IN VARCHAR2 DEFAULT 'B',
                             p_codigoSwift     IN VARCHAR2 DEFAULT NULL,
                             p_banco           IN VARCHAR2 DEFAULT NULL,
                             p_cod_banco       IN NUMBER DEFAULT NULL,
                             p_pais            IN VARCHAR2 DEFAULT NULL,
                             p_cod_pais       IN NUMBER DEFAULT NULL)
    RETURN typ_bancos IS

      v_cod_swift GE_BANCOS.COD_SWIFT%TYPE;
      v_banco     GE_BANCOS.DESCRIPCION%TYPE;
      v_pais      BA_PAISES.DESCRIPCION%TYPE;
	  
      --Cursor Banco corresponsal
      CURSOR c_bancorresponsal /*(p_cod_swift VARCHAR2, p_banco VARCHAR2, p_pais VARCHAR2)*/ IS
         SELECT GBANC.COD_SWIFT COD_SWIFT, GBANC.COD_BANCO COD_BANCO, GBANC.DESCRIPCION DESCRIPCION, PAI.DESCRIPCION PAIS, ciu.descripcion nom_ciudad, ciu.cod_ciudad, pai.cod_pais
           FROM GE_BANCOS GBANC, cc_cta_bancarias b, ba_paises pai, ba_personas pe, ba_ciudades ciu, ba_direcciones dir
          WHERE gbanc.cod_banco = b.cod_banco
            AND ((b.cod_modalidad = 43 AND pag_gen.fu_obt_cod_entidad NOT BETWEEN 1000 AND 1999) OR (b.cod_modalidad = 45 AND pag_gen.fu_obt_cod_entidad BETWEEN 1000 AND 1999))
            AND b.estado = 'N'
            AND gbanc.estado = 'A'
            AND gbanc.cod_persona = pe.cod_persona
            AND pe.cod_pais = pai.cod_pais
            AND b.cod_moneda = 'USD'
            -- --------------
            AND ciu.cod_ciudad = dir.cod_ciudad
            and ciu.cod_pais = dir.cod_pais
            and dir.cod_pais = pai.cod_pais
            and dir.cod_persona = pe.cod_persona
            and dir.principal = 'S'
            -- --------------
            --AND gbanc.cod_swift IS NOT NULL
            AND UPPER(gbanc.descripcion) LIKE '%' || NVL(UPPER(v_banco), UPPER(gbanc.descripcion)) || '%'
            AND UPPER(nvl(gbanc.cod_swift, 'x')) LIKE '%' || NVL(UPPER(v_cod_swift), UPPER(nvl(gbanc.cod_swift, 'x'))) || '%'
            AND UPPER(pai.descripcion) LIKE '%' || NVL(UPPER(v_pais), UPPER(pai.descripcion)) || '%'
            AND (p_cod_banco IS NULL OR gbanc.cod_banco = p_cod_banco)
            AND (p_cod_pais IS NULL OR pe.cod_pais = p_cod_pais);
            
      --Cursor Bancos destino
      CURSOR c_bancodestino IS
        select gbanc.cod_swift cod_swift, gbanc.cod_banco cod_banco, gbanc.descripcion descripcion, 
                pai.descripcion pais,  ciu.descripcion nom_ciudad, ciu.cod_ciudad, pai.cod_pais
           from ge_bancos gbanc, ba_paises pai, ba_ciudades ciu
          where gbanc.estado = 'A'
            and gbanc.ubicacion = 'E'
            ---- 04/07/2024 -----------------
            and gbanc.cod_pais = pai.cod_pais(+)
            and gbanc.cod_ciudad = ciu.cod_ciudad(+)
            and pai.cod_pais = ciu.cod_pais(+)
            and gbanc.cod_swift is not null
            -----------------------------------
            and upper(gbanc.descripcion) like '%' || nvl(upper(v_banco), upper(gbanc.descripcion)) || '%'
            and upper(nvl(gbanc.cod_swift, 'x')) like '%' || nvl(upper(v_cod_swift), upper(nvl(gbanc.cod_swift, 'x'))) || '%'
            and upper(pai.descripcion) like '%' || nvl(upper(v_pais), upper(pai.descripcion)) || '%'
            and gbanc.cod_banco = nvl(p_cod_banco,gbanc.cod_banco);
	 
	 -- entidades participantes
      CURSOR Entidad IS
         SELECT g.tipo, g.cod_swift, g.participante, nvl(g.cod_banco, g.cod_ente) cod_entidad
           FROM gv_snp_participantes g
          WHERE g.cod_persona <> fug_obt_per_entidad
            AND g.ind_hab_pte_hb = 'S'
            AND UPPER(g.participante) LIKE '%' || NVL(UPPER(v_banco), UPPER(g.participante)) || '%'
            AND UPPER(nvl(g.cod_swift, 'x')) LIKE '%' || NVL(UPPER(v_cod_swift), UPPER(nvl(g.cod_swift, 'x'))) || '%'
            AND (p_cod_banco IS NULL OR p_cod_banco = nvl(g.cod_banco, g.cod_ente))
            union all
         select 'CO', d.cod_swift_sub, d.subparticipante, null
         from ge_snp_patrocinador_det d
          where estado = 'S' 
          and ( d.cod_swift_padre = (UPPER(v_cod_swift)) or v_cod_swift is null   )
          ORDER BY 1, 3, 2 ;
          
       CURSOR c_bancos  IS
          SELECT GBANC.COD_SWIFT cod_swift, GBANC.COD_BANCO COD_BANCO, GBANC.DESCRIPCION DESCRIPCION, PAI.DESCRIPCION pais, ciu.descripcion nom_ciudad, ciu.cod_ciudad, pai.cod_pais
          FROM GE_BANCOS GBANC
          LEFT JOIN ba_personas per
          ON gbanc.cod_persona = per.cod_persona
          LEFT JOIN ba_direcciones dir
          ON per.cod_persona = dir.cod_persona and dir.principal = 'S'
          LEFT JOIN ba_paises pai
          ON dir.cod_pais = pai.cod_pais
          LEFT JOIN ba_ciudades ciu
          ON dir.cod_ciudad = ciu.cod_ciudad and dir.cod_pais = ciu.cod_pais
          -- --------------
          WHERE UPPER(gbanc.descripcion) LIKE '%' || NVL(UPPER(v_banco), UPPER(gbanc.descripcion)) || '%'
          AND UPPER(nvl(gbanc.cod_swift, 'x')) LIKE '%' || NVL(UPPER(v_cod_swift), UPPER(nvl(gbanc.cod_swift, 'x'))) || '%'
          AND UPPER(pai.descripcion) LIKE '%' || NVL(UPPER(v_pais), UPPER(pai.descripcion)) || '%'
          AND  gbanc.cod_banco = NVL(p_cod_banco,gbanc.cod_banco)
          AND per.cod_pais = NVL(p_cod_pais,per.cod_pais);
      
      v_retorno             typ_bancos := typ_bancos;
      v_detalleBanco        typ_detallebanco := typ_detallebanco;
      v_listaDetalleBancos  typ_listaDetalleBancos := typ_listaDetalleBancos();
      MSG_G_SIN_DATOS       CONSTANT VARCHAR2(15) := 'G_SIN_DATOS';
      v_can_detalles        NUMBER(5) := 0;
   BEGIN
      paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      v_retorno.cantidad := 0;

      -- Sanitizar variables
      v_cod_swift    := paw_uti.depurarTextos(p_codigoSwift, 20);
      v_banco        := paw_uti.depurarAlfanumerico(p_banco, 40);
      v_pais         := paw_uti.depurarTextos(p_pais, 35);

      IF p_tipo = 'C' THEN
         -- Banco corresponsal
         FOR reg IN c_bancorresponsal--(v_cod_swift, v_banco, v_pais)
         LOOP
            v_can_detalles               := v_can_detalles + 1;
            v_detalleBanco.codigoSwift   := substr(reg.cod_swift, 1, 20);
            v_detalleBanco.nombreEntidad := substr(reg.descripcion, 1, 60);
            v_detalleBanco.nombrePais    := substr(reg.Pais, 1, 35);
            v_detalleBanco.codigoBanco   := substr(reg.cod_banco, 1, 3);
            v_detalleBanco.nombreCiudad  := substr(reg.nom_ciudad, 1, 40);
            v_detalleBanco.codigoCiudad  := substr(reg.cod_ciudad, 1, 3);
            v_detalleBanco.codigoPais    := substr(reg.cod_pais, 1, 3);
            v_listaDetalleBancos.EXTEND;
            v_listaDetalleBancos(v_listaDetalleBancos.COUNT) := v_detalleBanco;
         END LOOP;
	    ELSIF p_tipo = 'S' THEN
	    -- Consulta de Entidades Registradas sipap.
        FOR e IN Entidad
        LOOP
		        v_can_detalles               := v_can_detalles + 1;
            v_detalleBanco.codigoSwift   := e.cod_swift;
            v_detalleBanco.nombreEntidad := substr(e.participante,1, 60);
            v_detalleBanco.codigoBanco   := e.cod_entidad;
            v_listaDetalleBancos.EXTEND;
            v_listaDetalleBancos(v_listaDetalleBancos.COUNT) := v_detalleBanco;
        END LOOP;
	    ELSIF p_tipo = 'T' THEN
         -- todos los bancos
         FOR reg IN c_bancos
         LOOP
            v_can_detalles                := v_can_detalles + 1;
            v_detalleBanco.codigoSwift   := substr(reg.cod_swift, 1, 20);
            v_detalleBanco.nombreEntidad := substr(reg.descripcion, 1, 60);
            v_detalleBanco.nombrePais    := substr(reg.Pais, 1, 35);
            v_detalleBanco.codigoBanco   := substr(reg.cod_banco, 1, 3);
            v_detalleBanco.nombreCiudad  := substr(reg.nom_ciudad, 1, 40);
            v_detalleBanco.codigoCiudad  := substr(reg.cod_ciudad, 1, 3);
            v_detalleBanco.codigoPais    := substr(reg.cod_pais, 1, 3);
            v_listaDetalleBancos.EXTEND;
            v_listaDetalleBancos(v_listaDetalleBancos.COUNT) := v_detalleBanco;
         END LOOP;
      ELSE
         -- Bancos destinos internacionales
         FOR reg IN c_bancodestino--(v_cod_swift, v_banco, v_pais)
         LOOP
            v_can_detalles               := v_can_detalles + 1;
            v_detalleBanco.codigoSwift   := substr(reg.cod_swift, 1, 20);
            v_detalleBanco.nombreEntidad := substr(reg.descripcion, 1, 60);
            v_detalleBanco.nombrePais    := substr(reg.Pais, 1, 35);
            v_detalleBanco.codigoBanco   := substr(reg.cod_banco, 1, 3);
            v_detalleBanco.nombreCiudad  := substr(reg.nom_ciudad, 1, 40);
            v_detalleBanco.codigoCiudad  := substr(reg.cod_ciudad, 1, 3);
            v_detalleBanco.codigoPais    := substr(reg.cod_pais, 1, 3);
            v_listaDetalleBancos.EXTEND;
            v_listaDetalleBancos(v_listaDetalleBancos.COUNT) := v_detalleBanco;
         END LOOP;
      END IF;
      -- Valida si encontro datos
      IF v_can_detalles = 0 THEN
         paw_uti.pr_mensajeUsuario(MSG_G_SIN_DATOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      v_retorno.listaDetalleBancos := v_listaDetalleBancos;
      v_retorno.cantidad := v_listaDetalleBancos.COUNT;
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
   END;

------------Obtener tipos de documentos---------------------------------------------------------
  FUNCTION fu_obtenerTiposDocumentos( p_tipo_operacion  IN VARCHAR2 DEFAULT NULL,
                                       p_cod_tipo_doc    IN NUMBER DEFAULT NULL,
                                       p_descripcion     IN VARCHAR2 DEFAULT NULL,
                                       p_abreviatura     IN VARCHAR2 DEFAULT NULL,
                                       p_tipo_persona    IN VARCHAR2 DEFAULT NULL)  RETURN typ_tiposdocumentos IS

        v_retorno                 typ_tiposdocumentos            := typ_tiposdocumentos;
        v_detalleTipoDoc          typ_detalleconsultadocumentos  := typ_detalleconsultadocumentos;
        v_listaDetalleTiposDocs   typ_listaconsultadocumentos    := typ_listaconsultadocumentos();
        MSG_G_SIN_DATOS           CONSTANT VARCHAR2(15)          := 'G_SIN_DATOS';
        
        v_cod_tra_padre            ge_movimientos.cod_tra_padre%TYPE := NULL;
        v_tip_ente                 ge_entes.tipo%TYPE := NULL;
        v_req_monto                VARCHAR2(1) := 'S';
        v_cod_tipo_ope             VARCHAR2(100);
	  
          -- tipos de documentos permitidos para sipap
        CURSOR c_tiposdocssipap is
          SELECT a.cod_tip_documento, a.abreviatura
          FROM ba_tip_documentos a
          WHERE a.estado = 'A'
          AND a.cod_tip_documento in (1, 2,3,5, 6, 43)  -- Solicitado por Edward V.
          -----
          AND a.cod_tip_documento = NVL(p_cod_tipo_doc,a.cod_tip_documento)
          AND UPPER(a.descripcion) LIKE '%'|| UPPER(NVL(p_descripcion,a.descripcion)) || '%'
          AND UPPER(a.abreviatura) LIKE '%'|| UPPER(NVL(p_abreviatura,a.abreviatura)) || '%'
          AND a.tip_persona = NVL(p_tipo_persona, a.tip_persona)
          ORDER BY 1, 2;
       
          -- todos los tipos de documentos  activos
        CURSOR c_tiposdocs is
          SELECT a.cod_tip_documento, a.abreviatura
          FROM ba_tip_documentos a
          WHERE a.estado = 'A'
          -----
          AND a.cod_tip_documento = NVL(p_cod_tipo_doc,a.cod_tip_documento)
          AND UPPER(a.descripcion) LIKE '%'|| UPPER(NVL(p_descripcion,a.descripcion)) || '%'
          AND UPPER(a.abreviatura) LIKE '%'|| UPPER(NVL(p_abreviatura,a.abreviatura)) || '%'
          AND a.tip_persona = NVL(p_tipo_persona, a.tip_persona)
          ORDER BY 1, 2;
      
   BEGIN
      v_retorno.cantidad := 0;      

      paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      --traducimos el codigo de operacion a uno conocido por el core
      prw_obt_lim_relacion(p_tipo_operacion, v_cod_tipo_ope, v_cod_tra_padre, v_req_monto,v_tip_ente);
      
      --si no encontramos mapeo trabajamos con el valor original
      IF v_cod_tipo_ope IS NULL THEN
        v_cod_tipo_ope := p_tipo_operacion;
      END IF;
 
      IF v_cod_tipo_ope = '036' THEN
        
         -- tipos documentos habilitados para sipap
         FOR reg IN c_tiposdocssipap
         LOOP
           v_detalleTipoDoc.codigoTipoDocumento := reg.cod_tip_documento;
           v_detalleTipoDoc.abreviaturaTipoDocumento := reg.abreviatura;
           v_listaDetalleTiposDocs.extend;
           v_listaDetalleTiposDocs(v_listaDetalleTiposDocs.count) := v_detalleTipoDoc;
         END LOOP;
         
	    ELSIF v_cod_tipo_ope IS NULL THEN
      
         -- todos los tipos de documentos
         FOR reg IN c_tiposdocs
         LOOP
           
           v_detalleTipoDoc.codigoTipoDocumento := reg.cod_tip_documento;
           v_detalleTipoDoc.abreviaturaTipoDocumento := reg.abreviatura;
           v_listaDetalleTiposDocs.extend;
           v_listaDetalleTiposDocs(v_listaDetalleTiposDocs.count) := v_detalleTipoDoc;
         END LOOP;
         
      END IF;
      
      -- Valida si encontro datos
      IF v_listaDetalleTiposDocs.Count = 0 THEN
         paw_uti.pr_mensajeUsuario(MSG_G_SIN_DATOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;    
      END IF;
      
      v_retorno.listaTiposDocs := v_listaDetalleTiposDocs;
      v_retorno.cantidad := v_listaDetalleTiposDocs.COUNT;
      
      RETURN v_retorno;
      
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
   END;
   ------------Obtener monedas---------------------------------------------------------
   FUNCTION fu_obtenerMonedas(p_tipo_operacion  IN VARCHAR2 DEFAULT NULL,
                              p_moneda_operacion IN VARCHAR2 DEFAULT NULL,
                              p_cod_moneda    IN VARCHAR2 DEFAULT NULL,
                              p_cod_iso     IN VARCHAR2 DEFAULT NULL,
                              p_cod_bcp     IN NUMBER DEFAULT NULL,
                              p_cod_pais    IN NUMBER DEFAULT NULL,
                              p_descripcion     IN VARCHAR2 DEFAULT NULL)  RETURN typ_monedas IS

        v_retorno                 typ_monedas            := typ_monedas;
        v_moneda                  typ_moneda             := typ_moneda;
        v_listaMonedas            typ_listamonedas       := typ_listamonedas();
        MSG_G_SIN_DATOS           CONSTANT VARCHAR2(15)          := 'G_SIN_DATOS';
       
        v_cod_tra_padre            ge_movimientos.cod_tra_padre%TYPE := NULL;
        v_tip_ente                 ge_entes.tipo%TYPE := NULL;
        v_req_monto                VARCHAR2(1) := 'S';
        v_cod_tipo_ope             VARCHAR2(100);
        v_periodo                  VARCHAR2(5);
        v_hora_fin                 VARCHAR2(15);
        v_codigo_moneda            VARCHAR2(15) := p_cod_moneda;
         	  
   -- tipos de monedas permitidos para sipap
        CURSOR c_monedas_sipap is
          SELECT m.cod_moneda, m.descripcion, m.cod_Pais, m.cod_mon_bco_central, m.cod_numerico, m.cod_mon_iso, m.cod_mon_entidad
          FROM ba_monedas m
          WHERE m.cod_moneda in ('USD', 'GS')
          -----
          AND m.cod_moneda = NVL(v_codigo_moneda, m.cod_moneda)
          AND NVL(m.cod_mon_iso,'X' ) = COALESCE(p_cod_iso, m.cod_mon_iso,'X')
          AND NVL(m.cod_mon_bco_central,0 )= COALESCE(p_cod_bcp, m.cod_mon_bco_central,0)
          AND m.cod_pais = NVL(p_cod_pais, m.cod_pais)
          AND UPPER(m.descripcion) LIKE '%'|| UPPER(NVL(p_descripcion,m.descripcion)) || '%';
       
          -- todas las monedas
        CURSOR c_monedas is
          SELECT m.cod_moneda, m.descripcion, m.cod_Pais, m.cod_mon_bco_central, m.cod_numerico, m.cod_mon_iso, m.cod_mon_entidad
          FROM ba_monedas m
          WHERE  m.cod_moneda = NVL(v_codigo_moneda, m.cod_moneda)
          AND NVL(m.cod_mon_iso,'X' ) = COALESCE(p_cod_iso, m.cod_mon_iso,'X')
          AND NVL(m.cod_mon_bco_central,0 )= COALESCE(p_cod_bcp, m.cod_mon_bco_central,0)
          AND m.cod_pais = NVL(p_cod_pais, m.cod_pais)
          AND UPPER(m.descripcion) LIKE '%'|| UPPER(NVL(p_descripcion,m.descripcion)) || '%';
      
   BEGIN
      v_retorno.cantidad := 0;      

      paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      --traducimos el codigo de operacion a uno conocido por el core
      prw_obt_lim_relacion(p_tipo_operacion, v_cod_tipo_ope, v_cod_tra_padre, v_req_monto,v_tip_ente);
      
      --si no encontramos mapeo trabajamos con el valor original
      IF v_cod_tipo_ope IS NULL THEN
        v_cod_tipo_ope := p_tipo_operacion;
      END IF;

      IF v_cod_tipo_ope = '036' THEN
         --verificamos el horario sipap
        v_periodo := pas_snp.fu_obt_est_horario('103','001','002');
         
        --si el horario esta cerrado retornamos la moneda de la operacion
         IF v_periodo <> 'A' THEN 
           IF p_moneda_operacion IS NOT NULL THEN
            v_codigo_moneda := p_moneda_operacion;
             v_cod_tipo_ope:=NULL; 
           END IF;
   
               
         ELSE
           -- monedas habilitados para sipap
           FOR reg IN c_monedas_sipap
           LOOP
              v_moneda.codigo           :=reg.cod_moneda;
              v_moneda.descripcion      :=reg.descripcion;
              v_moneda.codigo_numerico  :=reg.cod_numerico;
              v_moneda.codigo_bcp       :=reg.cod_mon_bco_central;
              v_moneda.codigo_iso       :=reg.cod_mon_iso;
              v_moneda.codigo_pais      :=reg.cod_pais;
                           
              v_listaMonedas.extend;
              v_listaMonedas(v_listaMonedas.count) := v_moneda;
           END LOOP;
         END IF;
      END IF;    
	    
      --consulta de monedas sin tener en cuenta la operacion
      IF v_cod_tipo_ope IS NULL THEN
      
         -- todas las monedas
         FOR reg IN c_monedas
         LOOP
            v_moneda.codigo           :=reg.cod_moneda;
            v_moneda.descripcion      :=reg.descripcion;
            v_moneda.codigo_numerico  :=reg.cod_numerico;
            v_moneda.codigo_bcp       :=reg.cod_mon_bco_central;
            v_moneda.codigo_iso       :=reg.cod_mon_iso;
            v_moneda.codigo_pais      :=reg.cod_pais;
                       
            v_listaMonedas.extend;
            v_listaMonedas(v_listaMonedas.count) := v_moneda;
         END LOOP;
         
      END IF;
      
      -- Valida si encontro datos
      IF v_listaMonedas.Count = 0 THEN
         paw_uti.pr_mensajeUsuario(MSG_G_SIN_DATOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;    
      END IF;
      
      v_retorno.listaMonedas := v_listaMonedas;
      v_retorno.cantidad := v_listaMonedas.COUNT;
     
      RETURN v_retorno;
      
   EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE (SQLERRM);
        DBMS_OUTPUT.PUT_LINE (SQLCODE);
         paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
   END;
-- ---------------------------------------------------------------------------------
FUNCTION fu_obtenerSnpHorarios(p_cod_periodo          IN ge_snp_horarios.cod_periodo%TYPE DEFAULT NULL,
                               p_estado               IN ge_snp_horarios.estado%TYPE DEFAULT NULL) RETURN typ_SnpPeriodos IS
                               
    v_retorno          typ_SnpPeriodos:=typ_SnpPeriodos();
    v_cantidadPeriodos NUMBER(3) := 0;
    listaPeriodos      typ_ListaSnpPeriodos := typ_ListaSnpPeriodos();
    
    CURSOR periodos IS
       SELECT COD_PERIODO, DESCRIPCION, ESTADO, FECHA, HOR_INICIO, HOR_FIN
         FROM ge_snp_horarios
         where COD_PERIODO = NVL(p_cod_periodo,cod_periodo)
         AND ESTADO = NVL(p_estado,estado);
         
 BEGIN
    paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

    FOR pe IN periodos
    LOOP
       DECLARE
          snpPeriodo typ_SnpPeriodo := typ_SnpPeriodo();
       BEGIN
          snpPeriodo.codigoPeriodo := pe.cod_periodo;
          snpPeriodo.descripcion   := pe.descripcion;
          snpPeriodo.estado        := pe.estado;
          snpPeriodo.fecha         := pe.fecha;
          snpPeriodo.horaInicio    := pe.hor_inicio;
          snpPeriodo.horaFin       := pe.hor_fin;
          v_cantidadPeriodos       := v_cantidadPeriodos + 1;
          listaPeriodos.EXTEND;
          listaPeriodos(listaPeriodos.COUNT) := snpPeriodo;
       END;
    END LOOP;
    v_retorno.cantidadPeriodos:=v_cantidadPeriodos;
    v_retorno.lista:= listaPeriodos;
     paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
     RETURN v_retorno;

 EXCEPTION
    WHEN OTHERS THEN
       paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       RETURN v_retorno;
 END;
 
  -- ---------------------------------------------------------------------------------
FUNCTION fu_obtenerHorarios(p_tipo_operacion  IN VARCHAR2,
                            p_codigo          IN VARCHAR2 DEFAULT NULL,
                            p_estado          IN VARCHAR2 DEFAULT NULL) RETURN typ_SnpPeriodos IS
                               
    v_retorno          typ_SnpPeriodos:= typ_SnpPeriodos();
    snpPeriodo         typ_SnpPeriodo := typ_SnpPeriodo();
    listaPeriodos      typ_ListaSnpPeriodos := typ_ListaSnpPeriodos();
    v_cod_tra_padre    ge_movimientos.cod_tra_padre%TYPE := NULL;
    v_tip_ente         ge_entes.tipo%TYPE := NULL;
    v_req_monto        VARCHAR2(1) := 'S';
    v_cantidadPeriodos NUMBER(3) := 0;
    
    v_cod_tipo_ope     VARCHAR2(5);
    v_inicio           VARCHAR2(15);
    v_fin              VARCHAR2(15);
    v_fecha_actual     VARCHAR2(10);


         
 BEGIN
    paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
    
    IF p_tipo_operacion = 'SIN_OPE' THEN
      IF(p_codigo = 50) THEN
        v_inicio := fug_obt_pardinamico('HOR_PRE_ESP_INICIO',7,71, null, null, null);
        v_fin := fug_obt_pardinamico('HOR_PRE_ESP_FIN',7,71, null, null, null);
                    
        snpPeriodo.codigoPeriodo := 50;
        snpPeriodo.descripcion   := 'Horario para contrato de cambio';
        --snpPeriodo.estado        := pe.estado;
        snpPeriodo.fecha         := SYSDATE;
        snpPeriodo.horaInicio    := v_inicio;
        snpPeriodo.horaFin       := v_fin;
        v_cantidadPeriodos       := v_cantidadPeriodos + 1;
        listaPeriodos.EXTEND;
        listaPeriodos(listaPeriodos.COUNT) := snpPeriodo;
      END IF;
      
      v_retorno.cantidadPeriodos:=v_cantidadPeriodos;
      v_retorno.lista:= listaPeriodos;
    ELSE
      prw_obt_lim_relacion(p_tipo_operacion, v_cod_tipo_ope, v_cod_tra_padre, v_req_monto,v_tip_ente);
      
      IF v_cod_tipo_ope = '036' THEN 
         v_retorno := fu_obtenerSnpHorarios(p_codigo, p_estado);
      END IF;
    END IF;  

    paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
    RETURN v_retorno;

 EXCEPTION
    WHEN OTHERS THEN
       paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       RETURN v_retorno;
 END;
 
  -----------Obtener contratos de cambio------------------
      FUNCTION fu_obtenerContratoCambio( p_cod_empresa        IN ba_personas.cod_persona%TYPE,
                                         p_cod_persona        IN ba_personas.cod_persona%TYPE,
                                         p_tipo_contrato      IN VARCHAR2,
                                         p_tipo_operacion     IN bw_cod_lim_relacion.nombre%TYPE DEFAULT NULL,
                                         p_cod_moneda         IN VARCHAR DEFAULT NULL) RETURN typ_respuestaContratoCambio IS

     
      v_retorno                  typ_respuestaContratoCambio := typ_respuestaContratoCambio;
      v_contratoCambio           typ_contratoCambio := typ_contratoCambio;
      v_listaContratosCambio     typ_listaContratosCambio := typ_listaContratosCambio();
      v_cod_persona              VARCHAR2(10);
      p_cod_operacion            VARCHAR2(10);
      p_cod_operaciones          VARCHAR2(10);
      v_cod_ope_arbitraje_venta  VARCHAR2(10);
      v_cod_tip_mensaje          VARCHAR2(10);
      MSG_G_SIN_DATOS            CONSTANT VARCHAR2(15) := 'G_SIN_DATOS'; /**No se encontraron registros*/
      v_can_detalles             NUMBER(3) := 0;
      v_tipo_contrato            VARCHAR2(1);
      v_exonerado                VARCHAR2(1);
      v_cod_tra_padre            ge_movimientos.cod_tra_padre%TYPE := NULL;
      v_tip_ente                 ge_entes.tipo%TYPE := NULL;
      v_req_monto                VARCHAR2(1) := 'S';
   
     --contratos de cambio
    CURSOR c_contrato(p_nro_documento IN VARCHAR2,
                    p_cod_operacion IN VARCHAR2) IS
     SELECT l.nro_operacion, l.cod_tip_operacion, lto.descripcion, l.cotizacion, l.cod_moneda,
            l.monto, l.mto_equ_local, l.mto_cargo1, l.mto_cargo2, l.mto_cargo3, l.mto_cargo4,
            l.cta_ref_contra3, l.mto_contra3, l.nro_diario
       FROM LC_OPE_PENDIENTES l, LC_TIP_OPERACIONES lto
      WHERE l.cod_tip_operacion = lto.cod_tip_operacion
        AND l.liquidado = 'N'
        AND l.ope_homebanking = 'S'
        AND l.nro_documento = p_nro_documento
        AND l.fec_operacion = trunc(SYSDATE)
        AND l.cod_tip_operacion = nvl(p_cod_operacion, l.cod_tip_operacion)
        AND l.cod_moneda = nvl(p_cod_moneda, l.cod_moneda);
        
      -- arbitraje
    CURSOR c_arbitraje(p_nro_documento IN VARCHAR2,
                       p_cod_operaciones IN VARCHAR2) IS
     SELECT l.nro_operacion, l.cod_tip_operacion, lto.descripcion, l.cotizacion, l.cod_moneda,
            l.monto, l.mto_equ_local, l.mto_cargo1, l.mto_cargo2, l.mto_cargo3, l.mto_cargo4,
            l.cta_ref_contra3, l.mto_contra3, l.nro_diario
       FROM LC_OPE_PEN_CAMBIOS l, LC_TIP_OPERACIONES lto
      WHERE l.cod_tip_operacion = lto.cod_tip_operacion
        AND l.liquidado = 'N'
        AND l.ope_homebanking = 'S'
        AND l.nro_documento = p_nro_documento
        AND (l.cod_tip_operacion IN (SELECT column_value FROM TABLE (fug_obt_tab_registro(p_cod_operaciones, ',' ))) OR p_cod_operaciones IS NULL)
        AND l.cod_moneda = nvl(p_cod_moneda, l.cod_moneda)
        AND l.fec_operacion = trunc(SYSDATE);
        
          --contratos de cambio y arbitraje
    CURSOR c_contratos_arbitraje(p_nro_documento IN VARCHAR2,
                                 p_cod_operacion IN VARCHAR2) IS
     SELECT l.nro_operacion, l.cod_tip_operacion, lto.descripcion, l.cotizacion, l.cod_moneda,
            l.monto, l.mto_equ_local, l.mto_cargo1, l.mto_cargo2, l.mto_cargo3, l.mto_cargo4,
            l.cta_ref_contra3, l.mto_contra3, l.nro_diario
       FROM LC_OPE_PENDIENTES l, LC_TIP_OPERACIONES lto
      WHERE l.cod_tip_operacion = lto.cod_tip_operacion
        AND l.liquidado = 'N'
        AND l.ope_homebanking = 'S'
        AND l.nro_documento = p_nro_documento
        AND l.fec_operacion = trunc(SYSDATE)
        AND l.cod_tip_operacion = nvl(p_cod_operacion, l.cod_tip_operacion)
        AND l.cod_moneda = nvl(p_cod_moneda, l.cod_moneda)
     UNION
     SELECT l.nro_operacion, l.cod_tip_operacion, lto.descripcion, l.cotizacion, l.cod_moneda,
            l.monto, l.mto_equ_local, l.mto_cargo1, l.mto_cargo2, l.mto_cargo3, l.mto_cargo4,
            l.cta_ref_contra3, l.mto_contra3, l.nro_diario
       FROM LC_OPE_PEN_CAMBIOS l, LC_TIP_OPERACIONES lto
      WHERE l.cod_tip_operacion = lto.cod_tip_operacion
        AND l.liquidado = 'N'
        AND l.ope_homebanking = 'S'
        AND l.nro_documento = p_nro_documento
        AND l.cod_tip_operacion = nvl(p_cod_operacion, l.cod_tip_operacion)
        AND l.cod_moneda = nvl(p_cod_moneda, l.cod_moneda)
        AND l.fec_operacion = trunc(SYSDATE);   
   BEGIN

     paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

     v_cod_persona := NVL(p_cod_empresa, p_cod_persona);
     --DDSI-52 - GDF - AGO 2017
     --Verificamos si la persona tiene exoneracion de gasto OUR
     v_exonerado := pal_tra.fu_ver_gto_exonerado(v_cod_persona);
     
      --obtenemos el cod_tip mensaje
      prw_obt_lim_relacion(p_tipo_operacion, v_cod_tip_mensaje, v_cod_tra_padre, v_req_monto,v_tip_ente);
     
     --codigo operacion correspondiente al tipo de contrato
      
      p_cod_operacion := lf_obtenerCodOpeContrato(p_tipo_contrato, v_cod_tip_mensaje);
     
     IF (p_tipo_contrato = 'C' OR p_tipo_contrato = 'V') THEN
       p_cod_operacion:= lf_obtenerCodOpeContrato(p_tipo_contrato,null);
       --contratos de cambio  
       FOR reg IN c_contrato(FUE_OBT_NRO_DOC_PERSONA(v_cod_persona),p_cod_operacion) LOOP
          v_can_detalles                     := v_can_detalles + 1;
          v_contratoCambio.numeroContrato    := reg.nro_operacion;
          v_contratoCambio.cotizacion        := reg.cotizacion;
          v_contratoCambio.codigoMoneda      := reg.cod_moneda;
          v_contratoCambio.monto             := reg.monto;
          v_contratoCambio.montoEqLocal      := reg.mto_equ_local;
          v_contratoCambio.montoCargo1       := reg.mto_cargo1;
          v_contratoCambio.montoCargo2       := reg.mto_cargo2;
          v_contratoCambio.montoCargo3       := reg.mto_cargo3;
          v_contratoCambio.montoCargo4       := reg.mto_cargo4;
          v_contratoCambio.cuentaReferencia3 := substr(reg.cta_ref_contra3, 15);
          v_contratoCambio.montoCargo3       := reg.mto_contra3;
          v_contratoCambio.numeroDiario      := reg.nro_diario;
          
          -- tipo contrato correspondiente al cod de operacion
          v_contratoCambio.tipoOperacion     := lf_obtenerTipoContratoCambio(reg.cod_tip_operacion);
                    
          IF v_contratoCambio.montoCargo2 IS NULL AND v_exonerado = 'S' THEN
             v_contratoCambio.montoCargo2 := 0;
          END IF;

          v_listaContratosCambio.extend;
          v_listaContratosCambio(v_listaContratosCambio.count) := v_contratoCambio;
        END LOOP;
     
     ELSIF(p_tipo_contrato = 'A') THEN
        p_cod_operaciones := lf_obtenerCodOpeContrato(p_tipo_contrato,v_cod_tip_mensaje);
        --Arbitraje
        FOR reg IN c_arbitraje(FUE_OBT_NRO_DOC_PERSONA(v_cod_persona),p_cod_operaciones) LOOP
          v_can_detalles                     := v_can_detalles + 1;
          v_contratoCambio.numeroContrato    := reg.nro_operacion;
          v_contratoCambio.cotizacion        := reg.cotizacion;
          v_contratoCambio.codigoMoneda      := reg.cod_moneda;
          v_contratoCambio.monto             := reg.monto;
          v_contratoCambio.montoEqLocal      := reg.mto_equ_local;
          v_contratoCambio.montoCargo1       := reg.mto_cargo1;
          v_contratoCambio.montoCargo2       := reg.mto_cargo2;
          v_contratoCambio.montoCargo3       := reg.mto_cargo3;
          v_contratoCambio.montoCargo4       := reg.mto_cargo4;
          v_contratoCambio.cuentaReferencia3 := substr(reg.cta_ref_contra3, 15);
          v_contratoCambio.montoCargo3       := reg.mto_contra3;
          v_contratoCambio.numeroDiario      := reg.nro_diario;
          -- tipo contrato correspondiente al cod de operacion
          v_contratoCambio.tipoOperacion     := lf_obtenerTipoContratoCambio(reg.cod_tip_operacion);
                    
          IF v_contratoCambio.montoCargo2 IS NULL AND v_exonerado = 'S' THEN
             v_contratoCambio.montoCargo2 := 0;
          END IF;

          v_listaContratosCambio.extend;
          v_listaContratosCambio(v_listaContratosCambio.count) := v_contratoCambio;
        END LOOP;
    ELSE
        --contratos de cambio y arbitraje
        FOR reg IN c_contratos_arbitraje(FUE_OBT_NRO_DOC_PERSONA(v_cod_persona),p_cod_operacion) LOOP
          v_can_detalles                     := v_can_detalles + 1;
          v_contratoCambio.numeroContrato    := reg.nro_operacion;
          v_contratoCambio.tipoOperacion     := reg.cod_tip_operacion;
          v_contratoCambio.cotizacion        := reg.cotizacion;
          v_contratoCambio.codigoMoneda      := reg.cod_moneda;
          v_contratoCambio.monto             := reg.monto;
          v_contratoCambio.montoEqLocal      := reg.mto_equ_local;
          v_contratoCambio.montoCargo1       := reg.mto_cargo1;
          v_contratoCambio.montoCargo2       := reg.mto_cargo2;
          v_contratoCambio.montoCargo3       := reg.mto_cargo3;
          v_contratoCambio.montoCargo4       := reg.mto_cargo4;
          v_contratoCambio.cuentaReferencia3 := substr(reg.cta_ref_contra3, 15);
          v_contratoCambio.montoCargo3       := reg.mto_contra3;
          v_contratoCambio.numeroDiario      := reg.nro_diario;
          
          -- tipo contrato correspondiente al cod de operacion
          v_contratoCambio.tipoOperacion     := lf_obtenerTipoContratoCambio(reg.cod_tip_operacion);
                      
          IF v_contratoCambio.montoCargo2 IS NULL AND v_exonerado = 'S' THEN
             v_contratoCambio.montoCargo2 := 0;
          END IF;
          


          v_listaContratosCambio.extend;
          v_listaContratosCambio(v_listaContratosCambio.count) := v_contratoCambio;
        END LOOP;
     END IF;
    
     -- Valida si encontro datos
     IF v_listaContratosCambio.Count > 0 THEN
        v_retorno.contratosCambio := v_listaContratosCambio;
     ELSE
        paw_uti.pr_mensajeUsuario(MSG_G_SIN_DATOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        RETURN v_retorno;
     END IF;

     return v_retorno;
  END;
     
--inicializacion del paquete
BEGIN

   pre_cam_for_numerico('.,');
   PRE_INI_APLICACION;
   PAE_CNF.G_COD_MODULO := 9; --Modulo caja
END PAW_GEN;
/
