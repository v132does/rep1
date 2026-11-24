CREATE OR REPLACE PACKAGE BODY IT."PAE_FAT" is

/*----------------------------------------------------------------------------------------------------------------
 Paquete para manejar funcionalidades de FATCA:
 Normativa propulsada por el fisco estadounidense o "IRS", que impone una serie de requerimientos
 procedimentales a las distintas instituciones financieras internacionales (o "FFIs"),
 con objeto de prevenir la evasión fiscal por parte de los ciudadanos de dicho país y/o sus residentes fiscales,
 sean estos últimos PFs como PJs ("US Person" o "US Entity").
 LCABRERA - ITC : abril/2014 - CRO-FATCA-ID
 ----------------------------------------------------------------------------------------------------------------*/


PROCEDURE PR_ACT_PER_FATCA (P_COD_PERSONA       IN BA_PERSONAS.COD_PERSONA%TYPE,
                            P_TIP_PERSONA       IN BA_PERSONAS.TIPO%TYPE,
                            P_COD_SEC_CONTABLE  IN GE_CLIENTES.COD_SEC_CONTABLE%TYPE DEFAULT NULL,
                            P_NOMINA            IN VARCHAR2 default 'N',
                            P_MENSAJE           OUT VARCHAR2,
                            P_ACT_CUENTA        IN VARCHAR2 default NULL)IS

  v_est_nuevo               ge_par_fatca.est_nuevo%type           :=null;
  v_est_anterior            ge_par_fatca.est_anterior%type        :=null;
  v_tip_indicio             ge_par_fatca.tip_indicio%type         :=null;
  v_tip_persona             ge_est_fatca.tip_persona%type         := P_TIP_PERSONA;
  v_cod_sec_contable        ge_par_fatca.cod_sec_contable%type    :=null;
  v_nro_identificador       ba_per_fatca.nro_identificador%type   :=null;
  v_lugar                   varchar2(400)                         :=null;
  v_plz_vencimiento         ge_est_fatca.plz_vencimiento%type     :=null;
  v_plz_caducidad           ge_est_fatca.plz_caducidad%type       :=null;
  v_tip_doc_fatca           ge_est_fatca.tip_doc_fatca%type       :=null;
  v_fec_vencimiento         ba_per_fatca.fec_vencimiento%type     :=null;
  v_fec_caducidad           ba_per_fatca.fec_caducidad%type       :=null;
  v_cod_pais                ba_paises.cod_pais%type := 13; --Se asigna 13 por Defecto EEUU
  v_msj_nue_estado          ge_est_fatca.msj_nue_estado%type      :=null;
  v_msj_documento           varchar2(400)                         :=null;
  v_des_estado              ba_cod_referencias.significado%type   :=null;
  v_observacion             varchar2(4000)                        :=null;
  v_obs_indicios            varchar2(2000)                        :=null;
  v_exi_nro_identificador   varchar2(1)                           :='N';
  v_exi_per_fatca           varchar2(1)                           :='N';
  v_reg_bloqueado           varchar2(1)                           :='N';
  v_ind_emi_msj_usuario     varchar2(1);
  v_ind_env_mail            varchar2(1);
  v_dir_cor_fatca           ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DIR_COR_FATCA');
  v_dir_cor_nomina          ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DIR_COR_NOMINA');
  v_destinatarios           ge_par_dinamicos.val_parametro%type;
  v_exi_cliente             varchar2(1);  
  v_actualiza               varchar2(1);
  v_des_tip_documento       ba_cod_referencias.significado%type   :=null;
  v_es_nomina               varchar2(1);
  v_est_ant_aux             ge_par_fatca.est_anterior%type        :=null;
  v_ind_bloqueo             ge_est_fatca.ind_bloqueo%type;
  v_tip_estado              ge_est_fatca.tip_estado%type;
  v_act_cuenta              varchar2(1) := nvl(p_act_cuenta,'N');
  v_tip_est_fatca           ge_est_fatca.tip_estado%type;
  v_tip_est_actual          ge_est_fatca.tip_estado%type;

function lf_obt_tip_estado (p_tip_estado     ge_est_fatca.tip_estado%type, 
                            p_act_cuenta     varchar2) return varchar2 is
v_tip_estado     ge_est_fatca.tip_estado%type; 
begin
   if p_tip_estado = 'E' and p_act_cuenta = 'S' then                      
    --Si cliente tiene estado tipo Pendiente y es Act. de cuenta buscar tipo Provisorio
     v_tip_estado := 'P' ;
   elsif p_tip_estado = 'P' and p_act_cuenta = 'S' then  
    --Si el cliente tiene estado tipo Provisorio y es Act. de Cuenta buscar tipo Provisorio                     
     v_tip_estado := 'P';
   elsif p_tip_estado = 'E' and p_act_cuenta = 'N' then                      
    --Si el cliente tiene estado tipo Pendiente y no es act. de cuenta buscar tipo Pendiente
     v_tip_estado := 'E';
   elsif p_tip_estado = 'P' and p_act_cuenta = 'N' then                      
    --Si el cliente tiene tipo Provisorio y no es Act. de Cuenta buscar tipo Provisorio
     v_tip_estado := 'P';
   end if;    
   return v_tip_estado;
end lf_obt_tip_estado;  
BEGIN

  v_lugar:= 'Verificar si el registro no esta bloqueado';
    begin
      select b.ind_bloqueo, g.tip_estado
        into v_reg_bloqueado, v_tip_est_actual
        from ba_per_fatca b, ge_est_fatca g
       where b.estado = g.est_fatca
         and b.cod_persona = P_COD_PERSONA;
    exception
      when no_data_found then
         v_reg_bloqueado := 'N';    
         v_tip_est_actual := 'E';
      when others then
         v_reg_bloqueado := 'N';
         v_tip_est_actual := 'E' ;         
    end;
  v_lugar:= 'Recuperar tipo de estado FATCA a Búscar';
  v_tip_est_fatca:= lf_obt_tip_estado(v_tip_est_actual, v_act_cuenta);
  
  v_lugar:= 'Verificar si persona esta registrada como cliente';
    begin
      select 'S'
        into v_exi_cliente
        from ge_clientes e
       where e.cod_persona = P_COD_PERSONA;
    exception
      when no_data_found then
         v_exi_cliente := 'N';      
      when others then
         v_exi_cliente := 'N';
    end;

  v_lugar:= 'Recuperar tipo de indicio';
  PAE_FAT.PR_OBT_IND_PER_FATCA(p_cod_persona, p_tip_persona, v_tip_indicio, v_obs_indicios);

  if v_reg_bloqueado = 'N' then
    v_lugar:= 'Recuperar estado anterior. Personas Físicas';
    
     v_lugar := 'Obtener:TIN-EIN-GIIN ( FATCA - TIN/EIN identificador para Entidades y Personas Físicas- identificador para Entidades Financieras Colaboradoras NO Norteamericanas).';
      BEGIN
        SELECT E.VAL_PARAMETRO
          INTO v_nro_identificador
          FROM BA_PER_DAT_ADICIONALES E
         WHERE PARAMETRO = 'TIN_EIN_FATCA'
           AND COD_PERSONA = P_COD_PERSONA;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
           raise_application_error(-20000, 'Error:'||v_lugar||'-'||sqlerrm);        
      END;
    
    if p_tip_persona = 'F' then
      begin
        select f.estado
          into v_est_anterior 
          from ba_per_fatca f
         where f.cod_persona = P_COD_PERSONA;

         v_exi_per_fatca := 'S';

      exception
         when no_data_found then
          v_est_anterior := 'CFPSI';
         when others then
            raise_application_error(-20000, 'Error:'||v_lugar||'-'||sqlerrm);
      end;
      v_lugar:= 'Verificar si la persona es Cliente Nómina o No';
      v_es_nomina := fug_es_cli_nomina(p_cod_persona);

    elsif p_tip_persona = 'J'  then
      v_lugar:= 'Recuperar registro en FATCA';
      begin
        select 'S'
          into v_exi_per_fatca
          from ba_per_fatca j
         where j.cod_persona = P_COD_PERSONA;
     
      exception
        when too_many_rows then
           v_exi_per_fatca := 'S';      
        when no_data_found then
           v_exi_per_fatca := 'N';
        when others then
          raise_application_error(-20000, 'Error:' || v_lugar || '-' || sqlerrm);
      end;

      v_lugar:= 'Recuperar sector contable';
      begin
        select e.cod_sec_contable
          into v_cod_sec_contable
          from ge_clientes e
         where e.cod_persona = P_COD_PERSONA;
      exception
        when no_data_found then
          v_cod_sec_contable := p_cod_sec_contable;
        when others then
           v_cod_sec_contable := p_cod_sec_contable;
      end;

      v_lugar:= 'Recuperar estado anterior. Personas Jurídicas';
      begin
        select t.estado
          into v_est_anterior
          from ba_per_fatca t
         where t.cod_persona = p_cod_persona;

         v_exi_per_fatca := 'S';

      exception
         when no_data_found then
              v_est_anterior := 'CFPI';            
         when others then
            raise_application_error(-20000, 'Error:'||v_lugar||'-'||sqlerrm);
      end;
      
      if v_exi_per_fatca = 'S' and nvl(p_act_cuenta,'N') = 'S' then

        begin 
          select e.est_nuevo
            into v_est_ant_aux
            from ge_est_fatca g, ge_par_fatca e
           where g.est_fatca = e.est_nuevo
             and ((v_tip_indicio != 'E' and nvl(e.cod_sec_contable,'N') = nvl(v_cod_sec_contable,'N'))
                 or v_tip_indicio = 'E')
             and nvl(e.ind_nro_identificador,'N') = nvl(v_exi_nro_identificador,'N')
             and g.tip_persona = 'J'
             and e.est_anterior = v_est_anterior
             and e.tip_indicio = v_tip_indicio
             and g.tip_estado = 'P';
         exception 
            when no_data_found then
                v_est_ant_aux := null;
            when others then
                raise_application_error(-20000, 'Error:'||v_lugar||'-'||sqlerrm);
          end;                    
        end if;
      
      
      if v_est_anterior is null then
        begin
           select e.est_nuevo
              into v_est_anterior
              from ge_est_fatca g, ge_par_fatca e
             where g.est_fatca = e.est_nuevo
               and nvl(e.cod_sec_contable,'N') = nvl(v_cod_sec_contable,'N')
               and g.tip_persona = 'J'
               and e.est_anterior = 'CFPI'
               and e.tip_indicio = 'N';
        exception 
          when no_data_found then
              v_est_anterior := 'CFPI';
          when others then
              raise_application_error(-20000, 'Error:'||v_lugar||'-'||sqlerrm);
        end;             
       end if;  
       
      v_lugar:= 'Verificar si es Cliente Nómina, Para Personas Jurídicas siempre debe ser N';
      v_es_nomina := 'N';
           
    end  if;
    

    v_lugar:= 'Verificar si existe Nro. Identificador';
    if v_nro_identificador is not null then
       v_exi_nro_identificador := 'S';
    end if;
        v_lugar:= 'Recuperar Nuevo Estado';
        begin
          select c.est_nuevo, e.plz_vencimiento, e.plz_caducidad, e.tip_doc_fatca, 
                 e.msj_nue_estado, e.ind_emi_msj_usuario, e.ind_env_mail, e.ind_bloqueo
            into v_est_nuevo, v_plz_vencimiento, v_plz_caducidad, v_tip_doc_fatca, 
                 v_msj_nue_estado, v_ind_emi_msj_usuario, v_ind_env_mail, v_ind_bloqueo
            from ge_par_fatca c, ge_est_fatca e
           where c.est_nuevo = e.est_fatca
             and c.est_anterior = nvl(v_est_ant_aux, v_est_anterior)
             and e.tip_persona = v_tip_persona
             and c.tip_indicio = v_tip_indicio
             and nvl(c.ind_nro_identificador,'N') = decode(v_tip_persona, 'F', 'N',nvl(v_exi_nro_identificador,'N'))
             and e.tip_asignacion = 'A'
             and e.tip_estado = v_tip_est_fatca
             and nvl(c.ind_nomina,'N') =  nvl(v_es_nomina,'N');                                                  
        exception
           when no_data_found then
              v_lugar := 'No Existe parametrización para: Est_Ant: '||v_est_anterior||' Tip.Indicio: '||v_tip_indicio;
             -- raise_application_error(-20000, 'Error: '||v_lugar||'-'||sqlerrm);
           when others then
              raise_application_error(-20000, 'Error:'||v_lugar||'-'||sqlerrm);
        end;
   
     v_lugar:= 'Obtener Vencimiento para Doc. FATCA';
     if v_plz_vencimiento is not null then
      v_fec_vencimiento := pag_cal.fu_obt_fec_actual(1) + v_plz_vencimiento;
     end if;

     v_lugar:= 'Obtener Caducidad par Doc. FATCA';
     if v_plz_caducidad is not null then
      v_fec_caducidad := to_date('31/12/' || to_number(to_char(pag_cal.fu_obt_fec_actual(1),'yyyy')+ v_plz_caducidad), 'dd/mm/yyyy');
     end if;

     v_lugar:= 'Obtener datos Estado FATCA';
     v_des_estado := pae_fat.fu_obt_des_estado(v_est_nuevo);

      v_lugar:= 'Obtener datos Tipo Doc. FATCA';
      if v_tip_doc_fatca is not null then
       begin
         select significado
           into v_des_tip_documento
           from ba_cod_referencias
          where dominio = 'TIP_DOC_FATCA'
            and val_minimo = v_tip_doc_fatca;
       exception
          when others then
          raise_application_error(-20000, 'Error:'||v_lugar||'-'||sqlerrm);
        end;
      end if;

     v_lugar:= 'Obtener mensaje sobre Estado Persona FATCA';
     if v_tip_doc_fatca is not null then
        v_msj_documento := v_msj_nue_estado||' . Doc. Requerido: '|| v_des_tip_documento;
     else 
        v_msj_documento := v_msj_nue_estado;
     end if;

     v_lugar:= 'Obtener mensaje a retornar sobre Estado FATCA Persona';
     P_MENSAJE := 'El estado actual del cliente para FATCA es ' || v_des_estado||'. '|| v_msj_documento;

     v_observacion:= 'Cliente: '||p_cod_persona ||'*'||P_MENSAJE||'* Detalle Indicios: '||v_obs_indicios;

    if  v_exi_per_fatca = 'S' then
     if (v_est_nuevo != v_est_anterior)
        or (v_est_anterior != nvl(v_est_ant_aux,v_est_anterior)) then
         v_lugar:= 'Actualizar Histórico Persona FATCA';

          PAE_FAT.PR_INS_HIS_PER_FATCA(p_cod_persona);

         v_lugar:= 'Actualizar registro Persona FATCA';
        begin
        update ba_per_fatca u
           set u.estado          = v_est_nuevo,
               u.est_anterior    = v_est_anterior,
               u.tip_documento   = v_tip_doc_fatca,
               u.fec_vencimiento = v_fec_vencimiento,
               u.fec_caducidad   = v_fec_caducidad,
               u.observacion     = v_observacion,
               u.tip_indicio     = v_tip_indicio, 
               u.ind_bloqueo     = v_ind_bloqueo,
               u.tip_actualizacion = 'A'
         where cod_persona       = p_cod_persona;
         
         v_actualiza := 'S';
         
         exception
           when others then
              raise_application_error(-20000, 'Error:'||v_lugar||'-'||sqlerrm);
         end;
      end if;   
    else
      v_lugar:= 'Insertar registro Persona FATCA';
      begin
        insert into ba_per_fatca
                   (cod_persona,    cod_pais,           estado,       est_anterior,
                    tip_documento,  fec_vencimiento,    fec_caducidad, observacion,
                    nro_identificador, tip_indicio, ind_bloqueo, tip_actualizacion)
             values (p_cod_persona,  v_cod_pais,        v_est_nuevo,  v_est_anterior,
                     v_tip_doc_fatca, v_fec_vencimiento, v_fec_caducidad, v_observacion,
                     v_nro_identificador, v_tip_indicio , v_ind_bloqueo, 'A');

          v_actualiza := 'S';             
       exception
         when others then
           null;
          --  raise_application_error(-20000, 'Error:'||v_lugar||'-'||sqlerrm);
       end;

    end if;
  else 
    P_MENSAJE := null;
  end if;

  v_lugar := 'Obteniendo Destinatarios';  
  if nvl(P_NOMINA,'N') = 'S' and v_dir_cor_nomina is not null then
     v_destinatarios := v_dir_cor_fatca||','||v_dir_cor_nomina;
  else
     v_destinatarios := v_dir_cor_fatca;
  end if; 

if nvl(v_ind_env_mail, 'N') = 'S' and v_destinatarios is not null  and  nvl(v_actualiza,'N') = 'S' then
    prg_env_mail(fug_obt_dir_correo,
                 v_destinatarios,
                'Persona en FATCA',
                'Se ha realizado la siguiente actualización: '||
                P_COD_PERSONA||' '||fue_obt_nom_persona(P_COD_PERSONA)||', Indicios: '||
                P_MENSAJE||
                chr(10)||'Atentamente.');
end if;                

if nvl(v_ind_emi_msj_usuario, 'N') = 'N' or   nvl(v_actualiza,'N') = 'N' then
   P_MENSAJE := null;
end if;

EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000, 'Error: PR_ACT_PER_FATCA '||v_lugar||'-'||sqlerrm);

END PR_ACT_PER_FATCA;


PROCEDURE PR_OBT_IND_PER_FATCA (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                P_TIP_PERSONA IN BA_PERSONAS.TIPO%TYPE,
                                P_TIP_INDICIO IN OUT VARCHAR2,
                                P_OBSERVACION IN OUT VARCHAR2) IS
  v_fatca_fuerte NUMBER(2) := 0;
  v_fatca_debil  NUMBER(2) := 0;
  v_exi_tel      NUMBER(2) := 0;
  v_indicio      VARCHAR2(1) := '';
  v_tip_persona  ba_personas.tipo%type  := P_TIP_PERSONA;
  v_lugar        varchar2(400)          := null;
  v_observacion  varchar2(2000)          := null;
  v_telefono     VARCHAR2(120);
  v_exi_ind_tel  NUMBER(2) := 0;
  ---DYDMR-1545-ITGF - Inconvenientes con FATCA - CD y Programa 12763
  CURSOR C_NPA IS -- para evaluar indicios de número telefónico
    SELECT lpad(ltrim(ltrim(ltrim(replace(area,' ', ''), ' '), '+') || ltrim(ltrim(replace(telefono,' ', ''), ' '), '+'), 1), 3) NPA,
           rpad(ltrim((ltrim(replace(area,' ', ''), ' ') || ltrim(replace(telefono,' ', ''), ' ')), '+'), 11, '\') Total_11,
           rpad(ltrim((ltrim(replace(area,' ', ''), ' ') || ltrim(replace(telefono,' ', ''), ' ')), '+'), 10, '\') Total_10,
           length(ltrim(ltrim(replace(area,' ', ''), ' '), '+') || ltrim(ltrim(replace(telefono,' ', ''), ' '), '+')) Cantidad,
           ltrim(ltrim(replace(area,' ', ''), ' '), '+') || ltrim(ltrim(replace(telefono,' ', ''), ' '), '+') Filtrado,
           substr( rpad(ltrim((ltrim(replace(area,' ', ''), ' ') || ltrim(replace(telefono,' ', ''), ' ')), '+'), 11, '\'),1,1) pri_digito,
           substr( rpad(ltrim((ltrim(replace(area,' ', ''), ' ') || ltrim(replace(telefono,' ', ''), ' ')), '+'), 11, '\'),2,3) sec_area
      FROM BA_TELEFONOS     
     WHERE COD_PERSONA = P_COD_PERSONA;

BEGIN
  v_lugar :='Es un indicio F/Fuerte si para esta Persona se cumplen algunas de estas condiciones.';
  v_lugar :='El País de Origen (Aplica para personas Físicas y Jurídicas).';
  BEGIN
    SELECT 1
      INTO V_FATCA_FUERTE
      FROM BA_PERSONAS
     WHERE pae_fat.fu_es_pai_fatca(COD_PAIS) = 'S'
       AND COD_PERSONA = P_COD_PERSONA;
    v_observacion := v_observacion ||'*'||'Pais Origen: EEUU';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_observacion := v_observacion ||'*'||'Pais Origen: NO es EEUU o no esta registrado';
  END;
  v_lugar :='Obtener: La Nacionalidad (Solo Personas Físicas). Persona: '||P_COD_PERSONA;
  BEGIN
    SELECT 1
      INTO V_FATCA_FUERTE
      FROM BA_PER_FISICAS
     WHERE pae_fat.fu_es_pai_fatca(COD_PAI_NACIONALIDAD) = 'S'
       AND COD_PERSONA = P_COD_PERSONA
       AND V_TIP_PERSONA = 'F';
    v_observacion := v_observacion ||'*'||'Pais Nac.: EEUU';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
     v_observacion := v_observacion ||'*'||'Pais Nac.: NO es EEUU o no esta registrado';
  END;

  v_lugar := 'Obtener: El País de la 2da. Nacionalidad de la Persona(Solo Personas Físicas). Persona: '||P_COD_PERSONA;
  BEGIN
    SELECT 1
      INTO V_FATCA_FUERTE
      FROM BA_PER_DAT_ADICIONALES
     WHERE PARAMETRO = 'COD_PAI_SEG_NACIONALIDAD'
       AND pae_fat.fu_es_pai_fatca(VAL_PARAMETRO) = 'S'
       AND COD_PERSONA = P_COD_PERSONA
       AND V_TIP_PERSONA = 'F';
       v_observacion := v_observacion ||'*'||'Pais Seg. Nac.: EEUU';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
       v_observacion := v_observacion ||'*'||'Pais Seg. Nac.: NO es EEUU o no esta registrado';
  END;
  v_lugar := 'Obtener: El País del Documento.';
  BEGIN
    SELECT 1
      INTO V_FATCA_FUERTE
      FROM BA_PERSONAS
     WHERE pae_fat.fu_es_pai_fatca(COD_PAI_DOCUMENTO) = 'S'
       AND COD_PERSONA = P_COD_PERSONA;
       v_observacion := v_observacion ||'*'||'Pais Doc.: EEUU';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
       v_observacion := v_observacion ||'*'||'Pais Doc.: NO es EEUU o no esta registrado';
  END;
  IF V_TIP_PERSONA = 'J' THEN
  v_lugar := 'Obtener:TIN_EIN ( FATCA - EIN identificador para Entidades ). Persona: '||P_COD_PERSONA;
    BEGIN
      SELECT 1
        INTO V_FATCA_FUERTE
        FROM BA_PER_DAT_ADICIONALES
       WHERE PARAMETRO = 'TIN_EIN_FATCA'
         AND COD_PERSONA = P_COD_PERSONA;
         v_observacion := v_observacion ||'*'||'EIN FATCA REGISTRADO';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_observacion := v_observacion ||'*'||'EIN FATCA NO REGISTRADO';
    END;
  END IF;

 v_lugar := 'Buscar Indicio DÉBIL: Únicamente si no hay Indicios Fuertes. Persona: '||P_COD_PERSONA;
  IF V_FATCA_FUERTE = 0 THEN
    /**  Es un indicio D/Débil si se cumplen algunas de estas condiciones **/
    v_lugar := 'Tipo dirección Fiscal.';
    BEGIN
      SELECT 1
        INTO V_FATCA_DEBIL
        FROM BA_DIRECCIONES
       WHERE TIPO = 'F'
         AND COD_PERSONA = P_COD_PERSONA
         AND pae_fat.fu_es_pai_fatca(COD_PAIS) = 'S'
         AND ROWNUM = 1;
       v_observacion := v_observacion ||'*'||'Dir. Fiscal: EEUU';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
       v_observacion := v_observacion ||'*'||'NO existe Dir. Fiscal: para EEUU';
    END;

    v_lugar:= 'País FATCA, para los demás tipos de direcciones.';
    BEGIN
      SELECT 1
        INTO V_FATCA_DEBIL
        FROM BA_DIRECCIONES a
       WHERE pae_fat.fu_es_pai_fatca(COD_PAIS) = 'S'
         AND COD_PERSONA = P_COD_PERSONA
         AND ROWNUM = 1;
      v_observacion := v_observacion ||'*'||'Dir. : EEUU';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
      v_observacion := v_observacion ||'*'||'No existe Dir. registrada para EEUU';
    END;
    v_lugar := 'Verificando: SI Código Postal corresponde a EEUU. Persona: '||P_COD_PERSONA;
    BEGIN
      SELECT 1
        INTO V_FATCA_DEBIL
        FROM BA_DIRECCIONES
       WHERE pae_fat.fu_es_pai_fatca(COD_PAIS) = 'S'
         AND COD_PERSONA = P_COD_PERSONA
         AND COD_POSTAL IN (SELECT val_minimo
                              FROM BA_COD_REFERENCIAS
                             WHERE dominio = 'COD_POS_FATCA')
         AND ROWNUM =1;

      v_observacion := v_observacion ||'*'||'Cód. Postal: EEUU';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_observacion := v_observacion ||'*'||'No existe Cód. Postal registrado para EEUU ';
    END;
    
    v_lugar := 'Obtener:TIN ( FATCA - TIN Personas Físicas). Persona: '||P_COD_PERSONA;
    BEGIN
      SELECT 1
        INTO V_FATCA_DEBIL
        FROM BA_PER_DAT_ADICIONALES
       WHERE PARAMETRO = 'TIN_EIN_FATCA'
         AND COD_PERSONA = P_COD_PERSONA
         AND V_TIP_PERSONA = 'F';
         v_observacion := v_observacion ||'*'||'TIN FATCA REGISTRADO';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_observacion := v_observacion ||'*'||'TIN FATCA NO REGISTRADO';
    END;
    v_lugar := 'Verificando:SI Código Área corresponde. Persona: '||P_COD_PERSONA;
    
      FOR i IN C_NPA LOOP
        v_lugar := 'Evaluar números obtenidos. Persona: '||P_COD_PERSONA;
        IF i.cantidad = 10 AND i.total_10 = i.filtrado THEN
            BEGIN
              SELECT 1
                INTO v_exi_tel
                FROM ba_cod_referencias
               WHERE dominio = 'NUM_PLA_FATCA'
                 AND val_minimo = i.npa;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                v_exi_tel := 0;
            END;
    ---DYDMR-1545-ITGF - Inconvenientes con FATCA - CD y Programa 12763  
        ELSIF i.cantidad = 11 AND i.total_11 = i.filtrado
                 AND i.pri_digito = '1' THEN
            BEGIN
              SELECT 1
                INTO v_exi_tel
                FROM ba_cod_referencias
               WHERE dominio = 'NUM_PLA_FATCA'
                 AND val_minimo = i.sec_area;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                v_exi_tel := 0;
            END;
              
        END IF;
        If nvl(v_exi_tel,0) > 0 then
           v_telefono := v_telefono||'-'|| i.filtrado;
           v_exi_ind_tel := nvl(v_exi_ind_tel,0) + v_exi_tel;
           v_exi_tel     := 0;
        End If;
      END LOOP;
     if nvl(v_exi_ind_tel,0) > 0 then
        V_FATCA_DEBIL := 1;
        v_observacion := v_observacion ||'*'||'Área Tél. registrada para EEUU'||v_telefono;
     else
        v_observacion := v_observacion || '*' ||'No existe Área Tél. registrada para EEUU';
     end if; 

  END IF;

  v_lugar := 'Validación y retorno de resultado: Personas Físicas';
  IF p_tip_persona = 'F' then
    IF v_fatca_fuerte > 0 THEN
      v_indicio := 'F'; -- Fuerte
    ELSIF v_fatca_debil > 0 THEN
      v_indicio := 'D'; -- Débil
    ELSE
      v_indicio := 'N'; -- No Aplica
    END IF;
  ELSIF  p_tip_persona = 'J' then
    v_lugar := 'Validación y retorno de resultado: Personas Jurídicas';
    IF v_fatca_fuerte > 0 OR v_fatca_debil > 0 THEN
      v_indicio := 'E'; -- Si Tiene Indicios
    ELSE
      v_indicio := 'N'; -- No Aplica
    END IF;
  END IF;

   v_observacion := v_indicio ||'*'|| v_observacion;
   P_TIP_INDICIO := v_indicio;
   P_OBSERVACION := v_observacion;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
   P_TIP_INDICIO := v_indicio;
   P_OBSERVACION := NULL;
  WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR(-20000,'PAE_FAT: '||'-'||v_lugar||'-'||sqlerrm);
END PR_OBT_IND_PER_FATCA;

PROCEDURE PR_INS_HIS_PER_FATCA(P_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE) IS

v_lugar varchar2(100);
BEGIN

  v_lugar := 'Buscando datos de Persona en FATCA';

    begin
      insert into ba_per_fatca_his
        (cod_persona, cod_pais, estado, est_anterior, nro_identificador, tip_documento,
         fec_vencimiento, fec_caducidad, observacion, ind_bloqueo, usu_insercion, fec_insercion, 
         usu_modificacion, fec_modificacion, usu_ins_historico, fec_ins_historico, tip_indicio,
         tip_actualizacion, pro_actualizacion, fec_ult_act_estado, usu_ult_act_estado)
      select 
         f.cod_persona, f.cod_pais, f.estado, f.est_anterior, f.nro_identificador, f.tip_documento, 
         f.fec_vencimiento, f.fec_caducidad, f.observacion, f.ind_bloqueo, f.usu_insercion, f.fec_insercion, 
         f.usu_modificacion, f.fec_modificacion, user, sysdate, f.tip_indicio,
         f.tip_actualizacion, f.pro_actualizacion, f.fec_ult_act_estado, f.usu_ult_act_estado
        from ba_per_fatca f
       where f.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000, 'PAE_FAT: ' || '-' || v_lugar || '-' ||p_cod_persona || '-' || sqlerrm);
    END;

EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,'PAE_FAT: ' || '-' || v_lugar || '-' || sqlerrm);
END PR_INS_HIS_PER_FATCA;


PROCEDURE PR_ACT_FEC_CADUCIDAD IS

v_fec_actual               ge_calendarios.fec_actual%type := PAG_CAL.FU_OBT_FEC_ACTUAL(1);
v_plz_vto_fatca            number := to_number(NVL(FUG_OBT_PARDINAMICO('PLZ_VTO_FATCA'), 0));
v_fec_vencimiento          ba_per_fatca.fec_vencimiento%type;
RG_PERFAT                  BA_PER_FATCA%ROWTYPE;
v_lugar                    varchar2(400);
v_est_exp_vencimiento      ba_per_fatca.estado%type;
v_est_exp_caducidad        ba_per_fatca.estado%type;

CURSOR PER_FATCA IS
  select cod_persona, fec_caducidad, fec_vencimiento, est_actual, 
         est_anterior, observacion, tip_persona, nro_identificador, tip_documento
    from (select c.cod_persona cod_persona,
                 c.fec_caducidad fec_caducidad,
                 c.fec_vencimiento fec_vencimiento,
                 c.estado est_actual,
                 c.est_anterior est_anterior,
                 c.observacion observacion,
                 'F' tip_persona,
                 c.nro_identificador nro_identificador, 
                 c.tip_documento tip_documento
            from ba_per_fatca c
           where exists (select 1
                    from ba_per_fisicas f
                   where f.cod_persona = c.cod_persona)
            and (c.fec_vencimiento is not null
                or c.fec_caducidad is not null)                   
          union all
          select g.cod_persona cod_persona,
                 g.fec_caducidad fec_caducidad,
                 g.fec_vencimiento fec_vencimiento,
                 g.estado est_actual,
                 g.est_anterior est_anterior,
                 g.observacion observacion,
                 'J' tip_persona,
                 g.nro_identificador nro_identificador, 
                 g.tip_documento tip_documento
            from ba_per_fatca g
           where exists (select 1
                    from ba_per_juridicas j
                   where j.cod_persona = g.cod_persona)
            and (g.fec_vencimiento is not null
                or g.fec_caducidad is not null)) per_fatca
             WHERE EXISTS (SELECT 1
             FROM ge_est_fatca f
             WHERE f.est_exp_caducidad IS NOT NULL
             AND est_actual = f.est_fatca
             AND rownum < 2) /*agregado para que no de error en cierre operativo por estados no parametrizados C.O 07/01/22 DYDMR-19249*/
     order by tip_persona, cod_persona;

      
BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:= 1; end;
  FOR act_fatca IN per_fatca LOOP    

     if nvl(act_fatca.fec_vencimiento -1 ,v_fec_actual) < v_fec_actual then
     
       v_lugar := 'Buscando estado para Vencidos';
       begin
          select v.est_exp_vencimiento
            into v_est_exp_vencimiento
            from ge_est_fatca v
           where v.est_fatca = act_fatca.est_actual
             and v.est_exp_vencimiento is not null
             and rownum < 2 ;
        exception
          when no_data_found then
             v_lugar := 'No Existe parametrización'||act_fatca.est_actual||'-Persona'||act_fatca.cod_persona;
            raise_application_error(-20000, 'Error: '||v_lugar||'-'||sqlerrm);
          when others then
            v_lugar := 'Error al buscar estado vto.: '||act_fatca.est_actual;      
            raise_application_error(-20000,'Error:'||v_lugar||'-'||sqlerrm);
        end;
        if act_fatca.est_actual != v_est_exp_vencimiento then
          ----Preparar datos para actualizar en fatca   
          RG_PERFAT.COD_PERSONA       := act_fatca.cod_persona;
          RG_PERFAT.ESTADO            := v_est_exp_vencimiento;
          RG_PERFAT.EST_ANTERIOR      := act_fatca.est_actual;
          RG_PERFAT.OBSERVACION       := 'Actualizado en proc. Exp. Vto. y Caducidad.'||'-'||act_fatca.observacion ;
          RG_PERFAT.IND_BLOQUEO       := 'S';
          RG_PERFAT.FEC_VENCIMIENTO   := act_fatca.Fec_Vencimiento;
          RG_PERFAT.FEC_CADUCIDAD     := act_fatca.Fec_Caducidad;
          RG_PERFAT.NRO_IDENTIFICADOR := act_fatca.Nro_Identificador;
          RG_PERFAT.TIP_DOCUMENTO     := act_fatca.Tip_Documento;
          
          PAE_FAT.PR_ACT_BA_PER_FATCA(RG_PERFAT,'S');
        end if;
     end if;
   
     if nvl(act_fatca.fec_caducidad -1 ,v_fec_actual) < v_fec_actual then
     
       v_lugar := 'Buscando estado para Caducados';
       begin
          select c.est_exp_caducidad
            into v_est_exp_caducidad
            from ge_est_fatca c
           where c.est_fatca = act_fatca.est_actual  
             and c.est_exp_caducidad is not null
             and rownum < 2 ;
        exception
          when no_data_found then
            v_lugar := 'No Existe parametrización'||act_fatca.est_actual||'-Persona'||act_fatca.cod_persona;
            raise_application_error(-20000, 'Error: '||v_lugar||'-'||sqlerrm);
          when others then
            v_lugar := 'Error al buscar estado vto.: '||act_fatca.est_actual;      
            raise_application_error(-20000,'Error:'||v_lugar||'-'||sqlerrm);
        end;
     
       v_lugar:= 'Obtener Vencimiento para Doc. FATCA';
       if v_plz_vto_fatca is not null then
         v_fec_vencimiento := v_fec_actual + v_plz_vto_fatca;
       end if;
       if act_fatca.est_actual != v_est_exp_caducidad then
         ----Preparar datos para actualizar en fatca   
          RG_PERFAT.COD_PERSONA       := act_fatca.cod_persona;
          RG_PERFAT.ESTADO            := v_est_exp_caducidad;
          RG_PERFAT.EST_ANTERIOR      := act_fatca.est_actual;
          RG_PERFAT.FEC_VENCIMIENTO   := v_fec_vencimiento;
          RG_PERFAT.OBSERVACION       := 'Actualizado en proc. Exp. Vto. y Caducidad.'||'-'||act_fatca.observacion ;
          RG_PERFAT.IND_BLOQUEO       := 'S';     
          RG_PERFAT.FEC_CADUCIDAD     := act_fatca.Fec_Caducidad;
          RG_PERFAT.NRO_IDENTIFICADOR := act_fatca.Nro_Identificador;
          RG_PERFAT.TIP_DOCUMENTO     := act_fatca.Tip_Documento;
            

          PAE_FAT.PR_ACT_BA_PER_FATCA(RG_PERFAT,'S');
        end if;
     end if;
  END LOOP;

EXCEPTION
  WHEN OTHERS THEN
      raise_application_error(-20000,'Error : PAE_FAT.PR_ACT_FEC_CADUCIDAD:'||v_lugar||'-'||sqlerrm);
END PR_ACT_FEC_CADUCIDAD;

FUNCTION FU_ES_PAI_FATCA(P_COD_PAIS BA_PAISES.COD_PAIS%TYPE) RETURN VARCHAR2 IS
V_EXI_PAI_FATCA VARCHAR2(1);

BEGIN
  begin
    select 'S'
      into V_EXI_PAI_FATCA
      from ba_tab_dat_adicionales R
     where R.TAB_RELACION = 'BA_PAISES'
       and R.PARAMETRO = 'FATCA'
       AND R.VAL_PARAMETRO = 'S'
       AND R.REFERENCIA = TO_CHAR(P_COD_PAIS);
  exception
    when no_data_found then
       V_EXI_PAI_FATCA := 'N';
    when others then
       V_EXI_PAI_FATCA := 'N';
   end;
   
   return V_EXI_PAI_FATCA;
   
EXCEPTION
    WHEN NO_DATA_FOUND THEN
       V_EXI_PAI_FATCA := 'N';
       return V_EXI_PAI_FATCA;
    WHEN OTHERS THEN
       V_EXI_PAI_FATCA := 'N';
       return V_EXI_PAI_FATCA;       
END FU_ES_PAI_FATCA;


PROCEDURE PR_ACT_BA_PER_FATCA
 (RP_PERFAT            IN BA_PER_FATCA%ROWTYPE,
  P_ENV_MAIL           IN GE_EST_FATCA.IND_ENV_MAIL%TYPE DEFAULT NULL)
 IS
v_existe               varchar2(1);
v_actualiza            varchar2(1);
v_dir_cor_fatca        ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DIR_COR_FATCA');

---Actualizar ba_per_fatca
BEGIN
if rp_perfat.estado is not null then  
 begin
     select 'S'
       into v_existe
       from ba_per_fatca
      where cod_persona = rp_perfat.cod_persona;
   exception
     when too_many_rows then
       v_existe := 'S';
     when no_data_found then
       v_existe := 'N';
     when others then
       v_existe := 'N';
   end;

 if nvl(v_existe,'N') = 'N' then
   begin 
      insert into ba_per_fatca(cod_persona, cod_pais, estado, est_anterior, 
                               nro_identificador, tip_documento, fec_vencimiento, 
                               fec_caducidad, observacion, ind_bloqueo)
           values (rp_perfat.cod_persona, nvl(rp_perfat.cod_pais,13), rp_perfat.estado, rp_perfat.est_anterior, 
                   rp_perfat.nro_identificador, rp_perfat.tip_documento, rp_perfat.fec_vencimiento, 
                   rp_perfat.fec_caducidad, rp_perfat.observacion, nvl(rp_perfat.ind_bloqueo,'N'));
       v_actualiza := 'S';                   
    exception
      when others then
        raise_application_error(-20000,'Error. Al Insertar en ba_per_fatca'||sqlerrm);
    end;                   
 else
   PAE_FAT.PR_INS_HIS_PER_FATCA(rp_perfat.cod_persona);
 begin 
    update ba_per_fatca
        set estado            = rp_perfat.estado,
            est_anterior      = rp_perfat.est_anterior,
            nro_identificador = rp_perfat.nro_identificador,
            tip_documento     = rp_perfat.tip_documento,
            fec_vencimiento   = rp_perfat.fec_vencimiento,
            fec_caducidad     = rp_perfat.fec_caducidad,
            observacion       = rp_perfat.observacion,
            ind_bloqueo       = nvl(rp_perfat.ind_bloqueo, ind_bloqueo), 
            tip_actualizacion = 'A'
      where cod_persona = rp_perfat.cod_persona
        and cod_pais = nvl(rp_perfat.cod_pais, 13);
        v_actualiza := 'S';
  exception
    when others then
      raise_application_error(-20000,'Error. Al Actualizar ba_per_fatca'||sqlerrm);
  end;
 end if;  
 if nvl(P_ENV_MAIL,'N') = 'S' and v_dir_cor_fatca is not null  and  nvl(v_actualiza,'N') = 'S' then
    prg_env_mail(fug_obt_dir_correo,
                v_dir_cor_fatca,
                'Persona en FATCA',
                'Se ha realizado la siguiente actualización: '||
                rp_perfat.cod_persona||' '||fue_obt_nom_persona(rp_perfat.cod_persona)||', Indicios: '||
                rp_perfat.observacion||
                chr(10)||'Atentamente.');
 end if;   
end if;  
                                    
exception
  when others then
        raise_application_error(-20000,'Error. PR_ACT_BA_PER_FATCA'||sqlerrm);
END;

PROCEDURE PR_ACT_PAR_FATCA (p_cod_persona    ba_personas.cod_persona%type,
                            p_tip_persona    ba_personas.tipo%type,
                            p_parametro      ba_per_dat_adicionales.parametro%type, 
                            P_val_parametro  ba_per_dat_adicionales.val_parametro%type)IS
 v_exi_parametro  varchar2(1);
 v_exi_registro   varchar2(1);

----Actualizar parametros FATCA
BEGIN

  begin
    select 'S'
      into v_exi_parametro
      from ba_per_def_adicionales e
     where e.parametro = p_parametro
       and (e.tip_persona = p_tip_persona
           or e.tip_persona in ('T','C'));
  exception
    when no_data_found then
      v_exi_parametro := 'N';
    when others then
      v_exi_parametro := 'N';
  end;


if nvl(v_exi_parametro,'N') = 'S' then

  begin
    select 'S'
      into v_exi_registro
      from ba_per_dat_adicionales e
     where e.parametro = p_parametro
       and e.cod_persona = p_cod_persona;
  exception
    when no_data_found then
      v_exi_registro := 'N';
    when others then
      v_exi_registro := 'N';
  end;

  if nvl(v_exi_registro,'N') = 'S' then

    begin
      if p_val_parametro is null then
      begin
        delete from BA_PER_DAT_ADICIONALES
         where parametro = p_parametro
           and COD_PERSONA = p_cod_persona;
       exception
          when no_data_found then
              null;
          when others then
              null;
       end;
      else
       begin
        update BA_PER_DAT_ADICIONALES
           set val_parametro = p_val_parametro
         where parametro = p_parametro
           and COD_PERSONA = p_cod_persona;
        exception
           when no_data_found then
              null;
           when others then
              null;          
        end;
      end if;
    exception
      when others then
        raise_application_error(-20000,'Error. Al Actualizar parámetro FATCA' || sqlerrm);
    end;
  else
   if p_val_parametro is not null then
     begin
       insert into BA_PER_DAT_ADICIONALES
         (parametro, val_parametro, cod_persona)
       values
         (p_parametro, to_char(p_val_parametro), p_cod_persona);
     exception
       when others then
          raise_application_error(-20000,'Error. Al insertar parámetro FATCA'||sqlerrm);
     end;
   end if;     
  end if;
end if;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
   null;
  WHEN OTHERS THEN
   raise_application_error(-20000,'Error. en PR_ACT_PAR_FATCA'||sqlerrm);
END;

PROCEDURE PR_VAL_GIIN is

Cursor dat_fatca is
     Select f.cod_persona, p.nom_completo, c.descripcion des_pai_itgf, substr(f.nro_identificador,6,30) giin_itgf
        from ba_per_fatca f, ba_personas p, ba_paises c
       where f.cod_persona = p.cod_persona
         and p.cod_pais = c.cod_pais  
         and (upper(f.nro_identificador) like '%GIIN%' 
             or upper(f.nro_identificador) like '%EIN%');

v_lugar      varchar2(400) := null;
v_can_datos  number := 0;             

procedure lp_act_dat_giin is
PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo estos cambios
begin  
    begin
      v_lugar := ' Borrar primera fila incorrecta (es el titulo de los campos)';
      delete from GE_FAT_GIIN_TMP t
       where t.giin like '%GIIN,FINm,CountryNm%';
    exception
      when others then
        null;
    end;


     begin
     v_lugar := ' Lleva la descripcion del pais al campo des_pais por que estos registros tuvieron mas " (separadores) que los esperados.';
       update ge_fat_giin_tmp g
          set g.des_pais = g.origen, 
              g.origen = null
        where g.origen is not null;
     exception
       when others then
         null;
     end;
     begin
     v_lugar := ' Actualiza el origen a IRS luego de haber actualizado la descripción del País';
       update ge_fat_giin_tmp g
          set g.origen = 'IRS'
        where g.origen is null;
     exception
       when others then
         null;
     end;     
     begin      
       v_lugar := ' Limpia los campos importados de posibles comillas demás.';
        update ge_fat_giin_tmp g
        set g.giin = replace(g.giin, '"',''), 
            g.nom_entidad = replace(g.nom_entidad, '"',''),
            g.des_pais = replace(g.des_pais, '"','');
      exception
        when others then
          null;
      end;
commit;
end lp_act_dat_giin;

         
  BEGIN
    begin         
      select count(*)  
        into v_can_datos
        from ge_fat_giin_tmp;
    exception
      when no_data_found then
        v_can_datos := 0;
      when others then
        v_can_datos := -1;
        v_lugar := ' Error al obtener datos de tabla temporal. Favor Verifique! ';        
    end;
    ---Si no se encuentran datos
    if nvl(v_can_datos,0) = 0 then
       v_lugar := ' Antes de procesar debe realizar la importación de lista GIIN-IRS. Favor Verifique! ';
    end if;


   IF nvl(v_can_datos,0) > 0 THEN
       lp_act_dat_giin;
       FOR df IN dat_fatca LOOP
         v_lugar := ' Evaluar GIIN FATCA vs. GIIN importados de la IRS. ';
         begin        
           v_lugar := ' Act. datos de Persona por GIIN Existente en Lista Importada. ';
           update ge_fat_giin_tmp gi
              set gi.cod_persona  = df.cod_persona,
                  gi.nom_completo = df.nom_completo,
                  gi.des_pai_itgf = df.des_pai_itgf
            where gi.giin         = df.giin_itgf;
            
          exception
            when others then
                 raise_application_error(-20000,'Error:'||v_lugar ||sqlerrm);
          end;
          
          if SQL%NOTFOUND then
              v_lugar := ' Act. datos de Persona por GIIN NO Existente en Lista Importada.';         
              begin  
                insert into ge_fat_giin_tmp (giin, nom_entidad, des_pais, origen, cod_persona, 
                                             des_pai_itgf, nom_completo, 
                                             observacion)
                                     values (df.giin_itgf, null, null, 'ITGF', df.cod_persona,
                                             df.des_pai_itgf, df.nom_completo, 
                                             'GIIN registrado en ITGF no existe en lista importada de la IRS.');
              exception
                when others then
                 raise_application_error(-20000,'Error:'||v_lugar ||sqlerrm);
              end;
           end if;      

       END LOOP;
    ELSE
       raise_application_error(-20000,'Error:'||v_lugar);
    END IF;

END PR_VAL_GIIN;

PROCEDURE PR_GEN_DAT_CLIENTE (P_FEC_SAL_AGREGADO GE_CALENDARIOS.FEC_ACTUAL%TYPE default null) 
  IS
  
   v_fec_proceso       ge_calendarios.fec_actual%TYPE;
   v_mto_sal_julio     ge_per_fatca_tmp.sal_agr_julio%TYPE; ---Saldo al 1 de julio de 2014 (exluido tarjetas)
   v_fec_hab_ant       ge_calendarios.fec_anterior%TYPE;
   v_mto_sal_tar_julio ge_per_fatca_tmp.sal_agr_tar_julio%TYPE; ---Saldo de tarjetas al 1 de julio de 2014
   v_fec_sal_agregado  ge_calendarios.fec_actual%TYPE := NULL;

BEGIN
  
   v_fec_sal_agregado := nvl(p_fec_sal_agregado, TRIM(fug_obt_pardinamico('FEC_SAL_AGREGADO')));
   v_fec_hab_ant      := pag_cal.fu_obt_fec_ant_hab(pag_cal.fu_obt_fec_actual(1), 1, 1);
   v_fec_proceso      := nvl(v_fec_sal_agregado, v_fec_hab_ant);      

   v_mto_sal_julio := 0;
   ---DYDMR-1545-ITGF - Inconvenientes con FATCA - CD y Programa 12763     
   v_mto_sal_tar_julio := 0;

   INSERT INTO ge_per_fatca_tmp
      (cod_persona, sal_agr_julio, sal_agr_tar_julio)
      SELECT g.cod_persona, v_mto_sal_julio, v_mto_sal_tar_julio
        FROM ge_clientes g
       WHERE NOT EXISTS (SELECT 1
                FROM ge_per_fatca_tmp t
               WHERE t.cod_persona = g.cod_persona);

   PAE_FAT.PR_ACT_DAT_CLIENTE(v_fec_proceso);

END PR_GEN_DAT_CLIENTE;


FUNCTION FU_OBT_DES_ESTADO(P_ESTADO GE_EST_FATCA.EST_FATCA%TYPE) RETURN VARCHAR2 IS
  v_des_estado     ge_est_fatca.descripcion%type;                    
BEGIN  
  select g.descripcion
    into v_des_estado
    from ge_est_fatca g
   where g.est_fatca = p_estado;
   return v_des_estado;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    v_des_estado := 'Estado FATCA no Registrado';
    return v_des_estado;
  WHEN TOO_MANY_ROWS THEN
    v_des_estado := 'Más de un Estado FATCA recuperado';
    return v_des_estado;
  WHEN OTHERS THEN
    v_des_estado := 'Error al recuperar Estado FATCA';
    return v_des_estado;
END FU_OBT_DES_ESTADO;


PROCEDURE PR_ACT_EST_ALT_CUENTA(P_NRO_CUENTA GE_CUENTAS.NRO_CUENTA%TYPE) IS

  v_cod_persona             ba_personas.cod_persona%type; 
  v_cod_sec_contable        ge_sec_contables.cod_sec_contable%type;
  v_nomina                  varchar2(1)             := 'N';
  v_mensaje                 ge_est_fatca.msj_nue_estado%type;
  v_lugar                   varchar2(400);

  
Cursor c_clientes is
  select b.cod_persona cod_persona, b.tipo tip_persona, c.cod_sec_contable cod_sec_contable
    from ba_personas b, ge_cta_clientes g, ge_clientes c
   where b.cod_persona = g.cod_persona
     and g.cod_persona = c.cod_persona(+)
     and g.nro_cuenta = p_nro_cuenta;

   
BEGIN

    FOR dp IN c_clientes LOOP
     v_lugar := 'Actualizar Estado en FATCA. Cliente: '||dp.cod_persona;
     
     v_nomina := fug_es_cli_nomina(dp.cod_persona, p_nro_cuenta);

     select decode(dp.tip_persona,'F',nvl(dp.cod_sec_contable,'N'),'J',dp.cod_sec_contable)
       into v_cod_sec_contable
       from dual;
       
        PAE_FAT.PR_ACT_PER_FATCA(dp.cod_persona,
                                 dp.tip_persona ,
                                 v_cod_sec_contable,
                                 v_nomina, 
                                 v_mensaje,
                                 'S'); ----Indica que es de actualización de Cuentas 


       
         END LOOP;
  exception
    when others then
      raise_application_error(-20001,'Error: ' || v_lugar ||' '|| sqlerrm);
                             
END;


PROCEDURE PR_ACT_DAT_CLIENTE(P_FEC_SAL_AGREGADO GE_CALENDARIOS.FEC_ACTUAL%TYPE) IS

   CURSOR c_dat_clientes IS
      SELECT c.cod_persona cod_persona, p.tipo tip_persona
        FROM ge_per_fatca_tmp c, ba_personas p
       WHERE c.cod_persona = p.cod_persona;

   v_lugar               VARCHAR2(200);
   v_tip_indicio         VARCHAR2(1) := '';
   v_det_indicio         VARCHAR2(2000) := NULL;
   v_mto_sal_agregado    ge_per_fatca_tmp.sal_agregado%TYPE; ---Saldo a una fecha determinada (exluido tarjetas)
   v_fec_sal_agregado    ge_calendarios.fec_actual%TYPE;
   v_mto_sal_agr_tarjeta ge_per_fatca_tmp.sal_agr_tarjeta%TYPE; ---Saldo a una fecha determinada

BEGIN
   v_lugar := 'Actualizar Clientes en tabla Temporal FATCA.';
     FOR lc IN c_dat_clientes LOOP
   
      pae_fat.pr_obt_ind_per_fatca(lc.cod_persona, lc. tip_persona, v_tip_indicio, v_det_indicio);
      v_mto_sal_agregado := fu_obt_sal_agregado(lc.cod_persona, p_fec_sal_agregado, 'A', 'C'); ---Saldo a una fecha determinada
      ---DYDMR-1545-ITGF - Inconvenientes con FATCA - CD y Programa 12763     
      v_mto_sal_agr_tarjeta := fu_obt_sal_agregado(lc.cod_persona, p_fec_sal_agregado, 'A', 'T'); ---Saldo a una fecha determinada     
      v_fec_sal_agregado    := p_fec_sal_agregado;
   
      BEGIN
         UPDATE ge_per_fatca_tmp t
            SET t.sal_agregado     = v_mto_sal_agregado,
                t.fec_sal_agregado = v_fec_sal_agregado,
                t.tip_ind_actual   = v_tip_indicio,
                t.det_ind_actual   = v_det_indicio,
                t.sal_agr_tarjeta  = v_mto_sal_agr_tarjeta
         
          WHERE t.cod_persona = lc.cod_persona;
      
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20001,'Error: ' || v_lugar || ' ' || sqlerrm);
      END;
   END LOOP;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20001, 'Error: ' || v_lugar || ' ' || SQLERRM);
END PR_ACT_DAT_CLIENTE;

FUNCTION FU_OBT_SAL_AGREGADO(p_cod_persona ge_clientes.cod_persona%TYPE,
                             p_fec_saldo   ge_calendarios.fec_actual%TYPE,
                             p_per_saldo   VARCHAR2,
                             p_tip_cuenta  VARCHAR2) RETURN NUMBER IS

   v_sal_agregado       ge_per_fatca_tmp.sal_agregado%TYPE := 0;
   v_tip_cli_saldo      ba_personas.tipo%TYPE;
   v_tip_cli_cuenta     ba_personas.tipo%TYPE;
   v_cli_pro_sustancial VARCHAR2(1);
   --CROFATCA-550 - HO - se agrega el parametro de fecha que para este caso servirá para buscar la
   --cotizacion en fecha tope de pariodo a reportar.-
   v_fec_periodo DATE := nvl(p_fec_saldo, to_date(fug_obt_pardinamico('FEC_SAL_AGREGADO'), 'dd/mm/yyyy'));

   ---DYDMR-1545-ITGF - Inconvenientes con FATCA - CD y Programa 12763
   CURSOR c_cuentas(p_cod_persona ge_clientes.cod_persona%TYPE) IS
   ----Suma de Cuentas distintas a Tarjetas
      SELECT nro_cuenta, fug_obt_cli_principal(nro_cuenta) cli_principal, saldo
        FROM (SELECT c.nro_cuenta, fug_obt_cli_principal(c.nro_cuenta) cli_principal, pag_gen.fu_con_mon_a_moneda(l.cod_moneda, 'USD', l.sal_tot_cap, NULL, v_fec_periodo, NULL) saldo
                 FROM ge_sal_diarios l, ge_cta_clientes c, ge_est_cuentas e, ge_par_dinamicos i, ge_cuentas u
                WHERE l.nro_cuenta = c.nro_cuenta
                      AND c.cod_modulo = e.cod_modulo
                      AND c.cod_modalidad = e.cod_modalidad
                      AND c.cod_modulo = u.cod_modulo
                      AND c.cod_modalidad = u.cod_modalidad
                      AND c.nro_cuenta = u.nro_cuenta
                      AND e.estado = u.estado
                      AND e.activo = 'S'
                      AND i.parametro = 'FAT_CTA_AFECTADAS'
                      AND c.cod_modulo = i.cod_modulo
                      AND c.cod_modalidad = i.cod_modalidad
                      AND i.val_parametro = 'S'
                      AND c.cod_modulo != 5
                      AND l.sal_tot_cap > 0
                      AND c.cod_persona = p_cod_persona
                      AND l.fecha = p_fec_saldo
                      AND p_tip_cuenta = 'C' ---Parametro indica saldos de Cuentas que no sean tarjetas
               UNION ALL
               ----Suma de Cuentas distintas a Tarjetas con Saldo Actual    
               SELECT c.nro_cuenta, fug_obt_cli_principal(c.nro_cuenta) cli_principal, pag_gen.fu_con_mon_a_moneda(l.cod_moneda, 'USD', (nvl(l.sal_facturar, 0) + nvl(l.sal_facturado, 0) + nvl(l.sal_financiado, 0) + nvl(l.sal_cuo_pendientes, 0))) * -1 saldo
                 FROM ta_cta_tarjetas l, ge_cta_clientes c, ge_est_cuentas e, ge_par_dinamicos i, ge_cuentas u
                WHERE l.nro_cuenta = c.nro_cuenta
                      AND c.cod_modulo = e.cod_modulo
                      AND c.cod_modalidad = e.cod_modalidad
                      AND c.cod_modulo = u.cod_modulo
                      AND c.cod_modalidad = u.cod_modalidad
                      AND c.nro_cuenta = u.nro_cuenta
                      AND e.estado = u.estado
                      AND e.activo = 'S'
                      AND i.parametro = 'FAT_CTA_AFECTADAS'
                      AND c.cod_modulo = i.cod_modulo
                      AND c.cod_modalidad = i.cod_modalidad
                      AND i.val_parametro = 'S'
                      AND c.cod_modulo = 5
                      AND ((nvl(l.sal_facturar, 0) + nvl(l.sal_facturado, 0) + nvl(l.sal_financiado, 0) + nvl(l.sal_cuo_pendientes, 0))) < 0 ---Se debe considerar las tarjetas que tengan saldo a favor (pago mayor a deuda)
                      AND c.cod_persona = p_cod_persona
                      AND p_per_saldo = 'A'
                      AND p_tip_cuenta = 'T' ---Parametro indica saldos de Cuentas que sean tarjetas            
               UNION ALL
               ----Suma de Cuentas distintas a Tarjetas con Saldo Histórico    
               SELECT c.nro_cuenta, fug_obt_cli_principal(c.nro_cuenta) cli_principal, pag_gen.fu_con_mon_a_moneda(h.cod_moneda, 'USD', (nvl(det.sal_actual, 0))) * -1 saldo
                 FROM cb_sal_inventarios_det_his det, cb_sal_inventarios_his h, ge_cta_clientes c, ge_est_cuentas e, ge_par_dinamicos i, ge_cuentas u
                WHERE det.nro_referencia = h.nro_referencia
                      AND det.fecha = h.fecha
                      AND det.nro_cuenta = c.nro_cuenta
                      AND h.cod_rubro LIKE '14210%'
                      AND c.cod_modulo = e.cod_modulo
                      AND c.cod_modalidad = e.cod_modalidad
                      AND c.cod_modulo = u.cod_modulo
                      AND c.cod_modalidad = u.cod_modalidad
                      AND c.nro_cuenta = u.nro_cuenta
                      AND e.estado = u.estado
                      AND e.activo = 'S'
                      AND i.parametro = 'FAT_CTA_AFECTADAS'
                      AND c.cod_modulo = i.cod_modulo
                      AND c.cod_modalidad = i.cod_modalidad(+)
                      AND i.val_parametro = 'S'
                      AND h.cod_modulo = 5
                      AND nvl(det.sal_actual, 0) < 0 ---Se debe considerar las tarjetas que tengan saldo a favor (pago mayor a deuda)
                      AND c.cod_persona = p_cod_persona
                      AND p_per_saldo = 'H'
                      AND h.fecha = p_fec_saldo
                      AND p_tip_cuenta = 'T'); ---Parametro indica saldos de Cuentas que sean tarjetas

   FUNCTION lf_es_cli_fisica(p_cod_persona ge_clientes.cod_persona%TYPE) RETURN VARCHAR2 IS
      --Funcion para identificar si la persona consultada es PF o PJ
      v_tip_persona VARCHAR2(1);
   BEGIN
      BEGIN
         SELECT p.tipo
           INTO v_tip_persona
           FROM ba_personas p
          WHERE p.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN OTHERS THEN
            v_tip_persona := 'F';
      END;
      RETURN v_tip_persona;
   
   END lf_es_cli_fisica;

BEGIN

   v_tip_cli_saldo := lf_es_cli_fisica(p_cod_persona);

   FOR c_saldo IN c_cuentas(p_cod_persona)
   LOOP
   
      v_tip_cli_cuenta := lf_es_cli_fisica(c_saldo.cli_principal);
      IF v_tip_cli_saldo = 'F' AND v_tip_cli_cuenta = 'J' THEN
         v_cli_pro_sustancial := pae_fat.fu_es_pro_sustancial(p_cod_persona, c_saldo.cli_principal);
      END IF;
      ---Lógica de obtención de saldo
      /*
      * 29-10-2017 
      * TODO esto se puede mejorar con un solo if ya que todos estos IF hacen lo mismo
      */
      IF v_tip_cli_cuenta = 'J' AND v_tip_cli_saldo = 'J' THEN
         --Si Cliente Princ de Cta es PJ y CLiente Saldo Es PJ (Sumar)       
         v_sal_agregado := v_sal_agregado + c_saldo.saldo;
      ELSIF v_tip_cli_cuenta = 'J' AND v_tip_cli_saldo = 'F' THEN
         --Si Cliente Princ de Cta es PJ y CLiente Saldo Es PF (Sumar solo si es propietario sustancial)
         IF nvl(v_cli_pro_sustancial, 'N') = 'S' THEN
            v_sal_agregado := v_sal_agregado + c_saldo.saldo;
         END IF;
      ELSIF v_tip_cli_cuenta = 'F' AND v_tip_cli_saldo = 'F' THEN
         --Si Cliente Princ de Cta es PF y CLiente Saldo Es PF (Sumar)     
         v_sal_agregado := v_sal_agregado + c_saldo.saldo;
      ELSIF v_tip_cli_cuenta = 'F' AND v_tip_cli_saldo = 'J' THEN
         --Si Cliente Princ de Cta es PF y CLiente Saldo Es PJ (Sumar)     
         v_sal_agregado := v_sal_agregado + c_saldo.saldo;
      END IF;
   
   END LOOP;

   RETURN nvl(v_sal_agregado, 0);

EXCEPTION
   WHEN OTHERS THEN
      v_sal_agregado := -99;
      RETURN nvl(v_sal_agregado, 0);
END FU_OBT_SAL_AGREGADO;




FUNCTION FU_ES_PRO_SUSTANCIAL(p_cod_per_fisica   ge_clientes.cod_persona%type,
                              p_cod_per_juridica ge_clientes.cod_persona%type)
  return varchar2 is
  ---Función para identificar si una PF es Propietario Sustancial
  ---DYDMR-1545-ITGF - Inconvenientes con FATCA - CD y Programa 12763  
  v_es_pro_sustancial varchar2(1);
begin
  begin
    select 'S'
      into v_es_pro_sustancial
      from ba_vinculos c
     where c.cod_persona = p_cod_per_juridica
       and c.cod_per_vinculo = p_cod_per_fisica
       and c.tipo = 'SF';
  exception
    when no_data_found then
      v_es_pro_sustancial := 'N';
    when others then
      v_es_pro_sustancial := 'N';
  end;
  return nvl(v_es_pro_sustancial, 'N');

end fu_es_pro_sustancial;


FUNCTION FU_OBT_SAL_CANCELADO(p_cod_persona in ge_clientes.cod_persona%TYPE,
                              p_fec_saldo   in ge_calendarios.fec_actual%TYPE
                        ) RETURN NUMBER IS

    
    cursor c_extractos (p_cod_persona GE_CTA_CLIENTES.COD_PERSONA%type,
                        f_inicio        date,
                        f_final         date
                        ) is
        select ext.nro_cuenta,max(ext.fec_extracto) 
          from ge_ext_cli_cuentas ext
         where ext.FEC_EXTRACTO between f_inicio and f_final 
           and ext.cod_persona = p_cod_persona
           and exists (select 1 
                         from ge_cuentas x
                        where x.nro_cuenta = ext.nro_cuenta                 
                          and x.cod_modalidad IN (31, 33, 41)) 
      group by ext.nro_cuenta;
        
    
    v_cuenta    ge_cta_clientes.nro_cuenta%type;
    v_fecha     date;
    v_total     number(18,2) := 0;
    v_mon_orig  number(18,2);
    v_mon_usd   number(18,2);
    v_currency GE_EXT_CLI_CUENTAS.COD_MONEDA%type;    
    v_fec_sal_agregado ge_calendarios.fec_actual%TYPE;
    ano number;
BEGIN
    -- tomar del par dinamico
    v_fec_sal_agregado := nvl(p_fec_saldo, to_date(fug_obt_pardinamico('FEC_SAL_AGREGADO'), 'dd/mm/yyyy'));
    
    ano := extract(year from v_fec_sal_agregado);    
    -- Tenemos en cuenta solo ese periodo del ano solicitado
    open c_extractos(
                    p_cod_persona,
                    to_date('01/01/'||ano, 'dd/mm/yyyy'),
                    to_date('30/12/'||ano, 'dd/mm/yyyy')
                    );
    
    loop
        FETCH c_extractos INTO v_cuenta,v_fecha;
        EXIT WHEN c_extractos%NOTFOUND;        
       
        -- Si el saldo actual es cero tomo el anterior,
        -- Si ambos son cero queda cero
        BEGIN
            select ext.cod_moneda, 
              case nvl(ext.sal_actual,0)
                   when 0 then nvl(ext.sal_anterior,0)
                   else nvl(ext.sal_actual,0)
              end as saldo
             into v_currency, v_mon_orig
             from ge_ext_cli_cuentas ext
            where ext.NRO_CUENTA = v_cuenta
              and ext.FEC_EXTRACTO = v_fecha;    
        EXCEPTION
            when no_data_found then
                raise_application_error(-20001, 'Fallo al buscar la moneda para: ' || v_cuenta);
            when others then
                raise_application_error(-20001, 'Error inesperado!!');
        END;
        v_mon_usd := PAG_GEN.fu_con_mon_a_moneda(
                                v_currency, --cod_mon_original
                                'USD', --cod_mon_destino
                                v_mon_orig, --P_MTO_MON_ORIGINAL
                                null,
                                v_fec_sal_agregado,
                                null
                                );
                                
        v_total := v_total + v_mon_usd;    
    end loop;--fin loop cursor extractos      
    close c_extractos;  
    return v_total;
EXCEPTION           
    when others then
        raise_application_error(-20001, 'Error inesperado!!');
END FU_OBT_SAL_CANCELADO;  

FUNCTION FU_OBT_INT_PAGADO(p_cod_persona in ge_clientes.cod_persona%TYPE,
                           p_fec_desde   in ge_calendarios.fec_actual%TYPE,
                           p_fec_hasta   in ge_calendarios.fec_actual%TYPE                        
                        ) RETURN NUMBER IS    
  v_tot_pagado     number(18,2) := 0;  
BEGIN
  BEGIN
      select sum(fub_con_mon_a_moneda(z.cod_moneda, 'USD', nvl(x.mto_interes,0),null,x.fec_pago))
        into v_tot_pagado
        from ah_cupones x, ge_cta_clientes y, ah_cta_certificados z
       where y.nro_cuenta = x.nro_cuenta
         and y.relacion = 'P'
         and x.nro_cuenta = z.nro_cuenta
         and y.cod_persona = p_cod_persona
         and x.estado = 'P'
         and x.fec_pago between p_fec_desde and p_fec_hasta;  
    EXCEPTION
        when no_data_found then
          v_tot_pagado := 0;
        when others then
          v_tot_pagado := 0;
    END;
    return v_tot_pagado;
    
    
END FU_OBT_INT_PAGADO;  
end PAE_FAT;
/

