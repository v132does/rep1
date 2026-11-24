CREATE OR REPLACE PROCEDURE IT.prg_pro_arc_mul
      (p_tip_extracto IN VARCHAR2 DEFAULT 'M', -- M Mensual, R Requerimiento, D solo movimientos del Dia
       p_tip_procesamiento VARCHAR2 DEFAULT NULL, -- G solo Generacion, E solo Envio, P o Null genera y envia
       p_nro_cuenta IN VARCHAR2 DEFAULT NULL,
       p_fec_requerimiento IN DATE  DEFAULT NULL,     
       p_cod_usuario VARCHAR2 DEFAULT USER ) is
-- Proceso de Generacion y Envio de Extractos en Formato Multicash
-- COREGEMUL-1 - Generacion automatica de archivos Multicash - NAF FEB/2018
-- Observacion: para generacion y envio automatico M - Mensual debe ejecutarse luego de la generacion de Extractos de ITGF
vg_proceso              varchar2(40);
vg_fec_actual           date;
vg_fec_extracto         date;
vg_tip_extracto         varchar2(1);
vg_nro_cuenta           GE_CUENTAS.NRO_CUENTA%type;
vg_hor_inicio           varchar2(8);
vg_hor_fin              varchar2(8);
vg_hor_ini_sub          varchar2(8);
vg_hor_fin_sub          varchar2(8);
vg_cod_banco            varchar2(2);
vg_separador            varchar2(1);
vg_lon_descripcion      number;
vg_dir_servidor         varchar2(100);
vg_ext_archivo          varchar2(5);
vg_programa             varchar2(60);
vg_det_error            varchar2(1000);
vg_fec_especifica       date;
vg_sin_movimientos      varchar2(1);
vg_des_errores          varchar2(1);
vg_tip_procesamiento    varchar2(1); -- G solo Generacion, E solo Envio
vg_cod_usuario          ba_usuarios.cod_usuario%type;
-- pk para cambio de estado extracto
vg_pk_cod_persona        ge_ext_cli_cuentas.cod_persona%type;
vg_pk_cod_extracto       ge_ext_cli_cuentas.cod_extracto%type;
vg_pk_fre_extracto       ge_ext_cli_cuentas.fre_extracto%type;
vg_pk_nro_cuenta         GE_CUENTAS.NRO_CUENTA%type;
vg_can_envio             varchar2(1);

-- Cursor de Entes configurados para envío Multicash
CURSOR c_ente is
   select distinct a.cod_ente, a.cod_persona, b.val_parametro str_cuentas
   from GE_ENTES a, 
        GE_PAR_ENTES b
   where a.tipo = 'MC'
        and a.cod_ente = b.cod_ente
        and b.parametro = 'MUL_NRO_CTA_EXTRACTO'
        and ','||trim(b.val_parametro)||',' like '%,'||trim(nvl(vg_nro_cuenta, b.val_parametro))||',%'  
   order by a.cod_persona;

-- Desglosa las cuentas del string recibido del parametro dinamico MUL_NRO_CTA_EXTRACTO
CURSOR c_cuentas(v_cuentas varchar2) is
   select nro_cuenta
   from (select regexp_substr(v_cuentas||',','[^,]+', 1, level) nro_cuenta from dual
         connect by regexp_substr(v_cuentas||',', '[^,]+', 1, level) is not null) ctas
   where nro_cuenta = nvl(vg_nro_cuenta, nro_cuenta);

-- Recupera contenido de archivos de una cuenta especifica
CURSOR c_contenido(v_nro_cuenta varchar2) is
   select a.nom_archivo, a.nro_linea, a.texto
   from ge_arc_multicash_tmp a
   where a.nro_cuenta = v_nro_cuenta
      and ((a.fec_extracto = vg_fec_extracto and vg_tip_extracto IN ('M','R')) or
          (a.fec_especifica = vg_fec_especifica and vg_tip_extracto = 'D'))
      and a.cod_tip_extracto = vg_tip_extracto
      and a.fec_extracto = vg_fec_extracto
      and decode(vg_tip_extracto, 'D', a.usu_insercion, 'R', a.usu_insercion, vg_cod_usuario) = vg_cod_usuario
      and estado IN ('G','F') -- recupera Generados y con Falla de envio
      and a.nom_archivo is NOT NULL -- no recupera registros de solo aviso de error
   order by a.nom_archivo, a.nro_linea;

-- Inicializa variables del proceso
PROCEDURE lp_ini_variables IS
BEGIN
  vg_proceso := 'lp_ini_variables';
  vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');
  vg_dir_servidor := pag_evo.g_repository;
  vg_ext_archivo := '.txt';
  vg_fec_actual := pag_cal.fu_obt_fec_actual(1);
  
  -- constantes
  vg_cod_banco := '7';
  vg_separador := ';';
  vg_lon_descripcion := 20;
  
  -- establece tipo de extracto
  IF upper(p_tip_extracto) = 'D' THEN
    vg_tip_extracto := 'D';
    vg_fec_especifica := nvl(p_fec_requerimiento, null);
  ELSIF upper(p_tip_extracto) = 'R' THEN
    vg_tip_extracto := 'R';
  ELSIF (upper(p_tip_extracto) = 'M' or p_tip_extracto IS NULL) THEN
    vg_tip_extracto := 'M';
  ELSE
     raise_application_error(-20000,vg_proceso ||' tipo de extracto ''' || p_tip_extracto || ''' no es valido.');
  END IF;
  -- establece cuenta
  IF p_nro_cuenta IS NOT NULL THEN
    vg_nro_cuenta := p_nro_cuenta;
    -- permite desplegar errores del proceso
    vg_des_errores := 'S';
  ELSE
    vg_des_errores := 'N';
    vg_nro_cuenta := NULL;
  END IF;
  -- establece fecha para vg_tip_extracto 'M'
  -- si es 'D' diario  o 'R' a requerimiento se establece en el proceso lp_gen_extractos
  IF vg_tip_extracto = 'M' then
   BEGIN
    select max(t.fec_extracto)
        into vg_fec_extracto
    from GE_ARQ_CLI_CUENTAS t;
   EXCEPTION
      WHEN others THEN
         raise_application_error(-20000,vg_proceso ||' '|| sqlerrm);
   END;
  END IF;
  -- Establece tipo de procesamiento
  IF upper(p_tip_procesamiento) = 'G' THEN
     vg_tip_procesamiento := 'G'; -- Solo Genera los Extractos
  ELSIF upper(p_tip_procesamiento) = 'E' THEN
     vg_tip_procesamiento := 'E'; -- Solo Envia los Extractos
  ELSIF upper(p_tip_procesamiento) = 'P' THEN -- Procesa la generacion y el envío
     vg_tip_procesamiento := NULL;
  ELSE
     vg_tip_procesamiento := NULL; -- Genera y Envia
  END IF;
  -- Establece usuario de procesamiento para Envios
  IF p_cod_usuario IS NOT NULL and p_tip_procesamiento = 'E' THEN
     vg_cod_usuario := UPPER(trim(p_cod_usuario));
  ELSE
     vg_cod_usuario := USER;
  END IF;
  -- Si tip procesamiento E Envia
  -- Recupera maxima fecha por tipo extracto 
  IF vg_tip_procesamiento = 'E' THEN
     select max(t.fec_extracto)
        into vg_fec_extracto
     from GE_ARC_MULTICASH_TMP t
     where t.cod_tip_extracto = vg_tip_extracto
        and t.estado IN ('G','F') -- recupera Generados y con Falla de envio
        -- si existe fecha especifica se incluye en la recuperacion
        and decode( vg_fec_especifica, null, t.fec_extracto, t.fec_especifica) = nvl(vg_fec_especifica, t.fec_extracto)
        -- si es requerimiento o diario se verifica que sea el mismo usuario
        and decode(vg_tip_extracto, 'R', t.usu_insercion, 'D', t.usu_insercion, vg_cod_usuario) = vg_cod_usuario
        and t.nom_archivo is NOT NULL -- no recupera registros de solo aviso de error
        ;
       
       IF vg_fec_especifica IS NULL THEN
          vg_fec_especifica := vg_fec_extracto;
       END IF;
  END IF;
  vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, null);
END;

-- Valida si la Cta es de la persona configurada 
-- Devuelve S si la cta es del cliente, caso contrario devuelve N
FUNCTION lf_val_cta_persona (p_cod_persona VARCHAR2, p_nro_cuenta VARCHAR2) 
  RETURN VARCHAR2 IS
  v_existe varchar2(1);
BEGIN
  vg_proceso := 'lf_val_cta_persona';
  v_existe := 'N';
  BEGIN        
      select 'S' into v_existe 
      from ge_cta_clientes a
         where a.cod_persona = p_cod_persona
         and a.nro_cuenta = p_nro_cuenta;   
  EXCEPTION
     WHEN no_data_found THEN
        v_existe := 'N';
     WHEN others then
        v_existe := 'N';
  END;
  return v_existe;
END;
  
-- Controla existencia de extractos
PROCEDURE lp_val_extractos IS
  v_existe              varchar2(1);
  v_fec_ini_mes         ge_movimientos.fecha%type;
BEGIN
  vg_proceso := 'lp_val_extractos';
  vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');
  
  --1 controlar cta especifica
  IF vg_nro_cuenta IS NOT NULL then
    -- control si cta esta configurada para envio multicash
    v_existe := NULL;
    BEGIN        
      select 'S' into v_existe 
      from ge_entes a, 
         ge_par_entes b
      where a.tipo='MC' 
         and a.cod_ente=b.cod_ente
         and b.parametro = 'MUL_NRO_CTA_EXTRACTO' 
         and ','||trim(b.val_parametro)||',' like '%,'||trim(vg_nro_cuenta)||',%';    
    EXCEPTION
      WHEN no_data_found THEN
         v_existe := 'N';
      WHEN others then
          raise_application_error(-20000, vg_proceso || ' '|| sqlerrm);
    END;
    IF nvl(v_existe,'N') = 'N' THEN
       raise_application_error(-20000, vg_proceso || ' - cta ' || vg_nro_cuenta || ' no configurada para envio multicash.');
    END IF;
  END IF;
  --Si es de Dia especifico
  IF vg_tip_extracto = 'D' THEN
    v_fec_ini_mes := to_date('01' || to_char(vg_fec_actual, '/mm/yyyy'),'dd/mm/yyyy');
    -- extractos a requerimiento
    -- verifica si es fecha habil ITGF
    IF pag_cal.fu_obt_fec_habil(vg_fec_especifica,1,1) <> vg_fec_especifica THEN
       raise_application_error(-20000, vg_proceso || to_char(vg_fec_especifica, 'dd/mm/yyyy') ||' no es fecha habil.');
    END IF;
    --controlar que fecha a requerimiento sea entre inicio de mes y ahora
    IF vg_fec_especifica IS NOT NULL THEN
      BEGIN
           select 'S' into v_existe from dual 
           where vg_fec_especifica BETWEEN v_fec_ini_mes AND vg_fec_actual;
      EXCEPTION
        WHEN no_data_found THEN
           v_existe := 'N';
        WHEN others THEN
           raise_application_error(-20000, vg_proceso || ' ' || sqlerrm);
      END;
      IF nvl(v_existe,'N') = 'N' THEN
         raise_application_error(-20000, vg_proceso || ' fecha debe ser del mes actual y no mayor a fecha ultimo cierre: ' || to_char(vg_fec_actual,'dd/mm/yyyy'));
      END IF;
    ELSE
       -- Si fecha requerimiento es nul se genera a la fecha del extracto a requerimiento itgf
       vg_fec_especifica := vg_fec_actual;
    END IF;
  END IF;
  -- controla existencia de extracto
  IF vg_nro_cuenta IS NOT NULL then    
     v_existe := NULL;
     BEGIN
       IF vg_tip_extracto IN ('D', 'R') THEN
          -- aun no existen los extractos en este punto del proceso
          v_existe := 'S';
       ELSE
          -- verifica existencia de cta en extracto mensual
          select 'S' into v_existe from GE_ARQ_CLI_CUENTAS where nro_cuenta = vg_nro_cuenta;
       END IF;
     EXCEPTION
       WHEN no_data_found THEN
          v_existe := 'N';
       WHEN others then
           raise_application_error(-20000, vg_proceso || ' '||sqlerrm);
     END;
     IF nvl(v_existe,'N') = 'N' THEN
        raise_application_error(-20000, vg_proceso || ' - cta ' || vg_nro_cuenta || ' sin extractos a fecha ' || to_char(vg_fec_actual,'dd/mm/yyyy'));
     END IF;        
  END IF;
  vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, null);
END;

-- Elimina acentos
FUNCTION lf_obt_mon_iso (p_cod_moneda VARCHAR2) 
  RETURN VARCHAR2 IS
v_mon_iso VARCHAR2(10);
BEGIN
  select cod_mon_iso 
    into v_mon_iso
  from ba_monedas 
    where cod_moneda = p_cod_moneda;
  RETURN(v_mon_iso);
END;

PROCEDURE lp_ins_reg_multicash (rm_mul IN GE_ARC_MULTICASH_TMP%ROWTYPE) IS
BEGIN
   insert into ge_arc_multicash_tmp (nro_linea, texto, cod_extracto, nro_cuenta, 
      nom_archivo, fec_extracto, cod_ente, cod_persona, 
      fre_extracto, estado, cod_tip_extracto, fec_especifica, det_error) 
   values (rm_mul.nro_linea, rm_mul.texto, rm_mul.cod_extracto, rm_mul.nro_cuenta,
      rm_mul.nom_archivo, rm_mul.fec_extracto, rm_mul.cod_ente, rm_mul.cod_persona, 
      rm_mul.fre_extracto, rm_mul.estado, rm_mul.cod_tip_extracto, rm_mul.fec_especifica,
      rm_mul.det_error); 
END;

-- Genera extracto multicash
procedure lp_gen_ext_mensual (p_nro_cuenta IN varchar2, p_cod_ente IN number) is
v_linea varchar2(300);
v_mov_monto            ge_movimientos.monto%type;
v_mov_descripcion      ge_movimientos.concepto%type;
v_debitos              ge_ext_cli_movimientos.mto_debito%type;
v_creditos             ge_ext_cli_movimientos.mto_credito%type;
v_deb_cabecera         ge_ext_cli_movimientos.mto_debito%type;
v_cre_cabecera         ge_ext_cli_movimientos.mto_credito%type;
v_nro_linea            number;
v_nom_archivo          varchar2(100);
v_fecha                date;
v_cod_extracto         number;
v_sal_anterior         ge_ext_cli_cuentas.sal_anterior%type;
v_nro_cuenta           ge_ext_cli_cuentas.nro_cuenta%type;
v_mto_cabecera         ge_ext_cli_cuentas.sal_actual%type;
v_nom_cliente          ge_ext_clientes.nom_cliente%type;
v_fre_extracto         ge_ext_clientes.fre_extracto%type;
v_exi_extracto         varchar2(1);
v_exi_movimientos      number;
v_cod_mon_iso          ba_monedas.cod_mon_iso%type;
v_cod_persona          ba_personas.cod_persona%type;
v_mensaje              varchar2(100);
r_garmul               ge_arc_multicash_tmp%rowtype;
-- Recupera registros de Extractos ITGF Generados
CURSOR c_extracto(v_nro_cuenta varchar2)  is
-- mensual
select fec_valor, fec_movimiento, mv.fec_insercion, mv.fec_extracto,
   sal_anterior, mto_credito, mto_debito, 
   mv.concepto, descripcion, nro_documento, 
   mv.cod_modulo, mv.cod_modalidad,
   nro_secuencia, hor_movimiento,
   cu.cod_extracto,
   mv.cod_tra_padre,
   c.nom_cliente,
   cu.cod_moneda,
   c.cod_persona,
   c.fre_extracto
from GE_ARQ_CLI_MOVIMIENTOS mv 
  join GE_ARQ_CLI_CUENTAS cu on cu.nro_cuenta = mv.nro_cuenta  and mv.fre_extracto=cu.fre_extracto
       and cu.fec_extracto=mv.fec_extracto and cu.cod_extracto=mv.cod_extracto
  join GE_TRANSACCIONES t on t.cod_transaccion = mv.cod_tra_padre and t.cod_modulo = mv.cod_modulo 
       and t.cod_modalidad = mv.cod_modalidad
  join GE_ARQ_CLIENTES c on c.COD_PERSONA=cu.cod_persona and c.FEC_EXTRACTO=cu.FEC_EXTRACTO
     and c.FRE_EXTRACTO=cu.FRE_EXTRACTO and c.COD_EXTRACTO=cu.COD_EXTRACTO
where mv.nro_cuenta = v_nro_cuenta
  and mv.fec_extracto = vg_fec_extracto
  and t.cod_modulo = mv.cod_modulo
  and t.cod_modalidad = mv.cod_modalidad  
  and mv.fec_extracto = cu.fec_extracto 
union all
-- mensual: sin movimientos
select null fec_valor, null fec_movimiento, cu.fec_insercion, cu.fec_extracto,
   cu.sal_anterior, 0 mto_credito, 0 mto_debito, 
   '** Sin Movimientos **' concepto, null descripcion, null nro_documento, 
   null cod_modulo, null cod_modalidad,
   null nro_secuencia, null hor_movimiento,
   cu.cod_extracto,
   null cod_tra_padre,
   null nom_cliente,
   cu.cod_moneda,
   cu.cod_persona,
   cu.fre_extracto
from GE_ARQ_CLI_CUENTAS cu
where vg_sin_movimientos = 'S'
   and cu.fec_extracto = vg_fec_extracto
   and cu.nro_cuenta = v_nro_cuenta
order by 3;

-- Recupera existencia de movimientos en extractos ITGF por cuenta
CURSOR c_exi_movimientos(v_nro_cuenta varchar2)  is
select count(1) movimientos
   from GE_ARQ_CLI_CUENTAS cu 
      join GE_ARQ_CLI_MOVIMIENTOS mv on cu.nro_cuenta = mv.nro_cuenta  and mv.fre_extracto=cu.fre_extracto
           and cu.fec_extracto=mv.fec_extracto and cu.cod_extracto=mv.cod_extracto
   where mv.nro_cuenta = v_nro_cuenta
      and mv.fec_extracto = vg_fec_extracto
      and mv.fec_extracto = cu.fec_extracto;
BEGIN
  vg_proceso := 'lp_gen_ext_mensual';
  v_nro_cuenta := p_nro_cuenta;
  v_debitos := 0;
  v_creditos := 0;
  v_deb_cabecera := 0;
  v_cre_cabecera := 0;
  v_nro_linea := 0;
  v_mto_cabecera := 0;
  vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');
  v_exi_extracto := 'N'; -- no existe extracto
  vg_sin_movimientos := 'N'; --con movimientos
  v_exi_movimientos := 0;
  v_cod_mon_iso := null;
  v_cod_persona := null;
  v_fre_extracto := null;

  
  -- controla existencia de cabecera de extractos y movimientos de la cuenta   
  OPEN c_exi_movimientos(v_nro_cuenta);
  FETCH c_exi_movimientos INTO v_exi_movimientos;
  IF v_exi_movimientos = 0 then
       vg_sin_movimientos := 'S'; -- sin movimientos
  END IF;
  CLOSE c_exi_movimientos;
  
  for reg in c_extracto(v_nro_cuenta) loop
     v_exi_extracto := 'S';
     v_fecha := reg.fec_extracto;
     v_mov_descripcion := upper(substr(reg.descripcion,1,vg_lon_descripcion));
     v_cod_extracto := reg.cod_extracto;
     v_sal_anterior := reg.sal_anterior;
     v_nom_cliente := reg.nom_cliente;
     v_cod_mon_iso := reg.cod_moneda;
     v_cod_persona := reg.cod_persona;
     v_fre_extracto := reg.fre_extracto;
     v_nom_archivo := 'UMSATZ_' || v_nro_cuenta || /*'_' ||*/ to_char(v_fecha,'dd-mm-yy') ;
           
     -- adecua monto a partir del extracto
     if reg.mto_debito is not null and reg.mto_debito <> 0 then
        v_mov_monto :=  reg.mto_debito * -1;
     else
        v_mov_monto :=  reg.mto_credito;
     end if;
     -- detalle (UMSATZ.TXT)
     v_linea := vg_cod_banco --1 (A 0 12) codigo de banco
     || vg_separador || v_nro_cuenta        --2 (A 0 24) cuenta
     || vg_separador || v_cod_extracto     --3 (N 1 4) ultimo extracto de la cuenta mas uno
     || vg_separador || to_char( reg.fec_valor, 'dd.mm.yy') --4 (X 8 8) fecha con el formato dd.mm.aa
     || vg_separador --5 (N 1 10)	primary note number [opcional]   
     || vg_separador --6 (A 0 27) note to payee 1 [optional]
     || vg_separador --7 (A 0 27)	bank posting text [opcional]
     || vg_separador --8 (0 0) not used
     || vg_separador || substr(reg.cod_tra_padre,1,4) --9 (A 0 4) text key [opcional]
     || vg_separador || reg.nro_documento --10 (A 0 16) referencia [optional]
     || vg_separador || trim(to_char(v_mov_monto,'999999999999999990.99')) --11 (N 1 18.2) amount
     || vg_separador --12 (0 0) not used
     || vg_separador --13 (0 0) not used
     || vg_separador || to_char( reg.fec_movimiento, 'dd.mm.yy') --14 (8 8) fecha con el formato dd.mm.aa
     || vg_separador --15 (0 0) not used
     || vg_separador --16 (0 0) not used
     || vg_separador || v_mov_descripcion --17 (A 0 27) note to payee 2 [opcional]
     || vg_separador --18 (A 0 27) note to payee 3 [opcional]
     || vg_separador --19 (A 0 27) note to payee 4 [opcional]
     || vg_separador --20 (A 0 27) note to payee 5 [opcional]
     || vg_separador --21 (A 0 27) note to payee 6 [opcional]
     || vg_separador --22 (A 0 27) note to payee 7 [opcional]
     || vg_separador --23 (A 0 27) note to payee 8 [opcional]
     || vg_separador --24 (A 0 27) note to payee 9 [opcional]
     || vg_separador --25 (A 0 27) note to payee 10 [opcional]
     || vg_separador --26 (A 0 27) note to payee 11 [opcional]
     || vg_separador --27 (A 0 27) note to payee 12 [opcional]
     || vg_separador --28 (A 0 27) note to payee 13 [opcional]
     || vg_separador --29 (A 0 27) note to payee 14 [opcional]
     || vg_separador --30 (A 0 27) business partner [opcional]
     || vg_separador --31 (A 0 27) business partner [opcional]
     || vg_separador --32 (A 0 12) bank key of the partner's bank [opcional]
     || vg_separador --33 (A 0 24) bank account number of the partner [opcional]
     || vg_separador || substr(reg.cod_tra_padre,1,3) --34 (A 0 3)  business transaction code [opcional]
     ;
     -- genera la linea si hay movimientos reales
     IF vg_sin_movimientos = 'N' THEN
        v_nro_linea := v_nro_linea + 1;
        
        r_garmul.nro_linea := v_nro_linea;
        r_garmul.texto := v_linea;
        r_garmul.cod_extracto := v_cod_extracto;
        r_garmul.nro_cuenta := v_nro_cuenta;
        r_garmul.nom_archivo := v_nom_archivo;
        r_garmul.fec_extracto := vg_fec_extracto;
        r_garmul.cod_ente := p_cod_ente;
        r_garmul.cod_persona := v_cod_persona;
        r_garmul.fre_extracto := v_fre_extracto;
        r_garmul.estado := 'G';
        r_garmul.cod_tip_extracto := vg_tip_extracto;
        r_garmul.fec_especifica := v_fecha;
        -- inserta registro multicash
        lp_ins_reg_multicash (r_garmul);
     END IF;
     
     -- acumula datos para cabecera (AUSZUG.TXT)
     v_creditos := v_creditos + reg.mto_credito;
     v_debitos := v_debitos + reg.mto_debito;  
  end loop;
  
  IF v_exi_extracto = 'S' THEN
     -- cabecera (AUSZUG.TXT)
     v_nom_archivo := 'AUSZUG_' || v_nro_cuenta || /*'_' ||*/ to_char(v_fecha,'dd-mm-yy');
     v_mto_cabecera := v_sal_anterior - v_debitos + v_creditos;
     
     v_deb_cabecera := v_debitos;
     v_cre_cabecera := v_creditos;
    
     -- recupera codigo iso de la moneda de la cuenta
     v_cod_mon_iso := lf_obt_mon_iso (v_cod_mon_iso);
    
     v_linea := vg_cod_banco --1 codigo de banco(A 0 12 bank key)
        || vg_separador || v_nro_cuenta --2 cuenta (A 0 24)
        || vg_separador || v_cod_extracto --3 (N 1 4) ultimo extraco de cuenta).append(1
        || vg_separador || to_char(v_fecha,'dd.mm.yy') --4 (X 8 8) fecha con formato dd.mm.aa
        || vg_separador || v_cod_mon_iso --5 (A 3 3) currency key
        || vg_separador || trim(to_char(v_sal_anterior,'999999999999999990.99')) --6 N 1 18.2 opening balance amount
        || vg_separador || trim(to_char(v_deb_cabecera,'999999999999999990.99')) --7 (N 1 18.2) debit total
        || vg_separador || trim(to_char(v_cre_cabecera,'999999999999999990.99')) --8 (N 1 18.2) credit total
        || vg_separador || trim(to_char(v_mto_cabecera,'999999999999999990.99')) --9 (N 1 18.2) closing balance amount
        || vg_separador || substr(v_nom_cliente, 1, 35) --10 (A 0 35) bank account holder
        || vg_separador --11 (A 0 35) special account name [opcional]
        || vg_separador --12 (X 8 8) life start [opcional]
        || vg_separador --13 (X 8 8) life end [opcional]
        || vg_separador --14 0 0 not used
        || vg_separador --15 0 0 not used
        || vg_separador --16 0 0 not used
        || vg_separador --17 0 0 not used
        || vg_separador || v_nro_linea --18 N 1 5 number of records in statement
        ;  
             
     r_garmul.nro_linea := 0;
     r_garmul.texto := v_linea;
     r_garmul.cod_extracto := v_cod_extracto;
     r_garmul.nro_cuenta := v_nro_cuenta;
     r_garmul.nom_archivo := v_nom_archivo;
     r_garmul.fec_extracto := vg_fec_extracto;
     r_garmul.cod_ente := p_cod_ente;
     r_garmul.cod_persona := v_cod_persona;
     r_garmul.fre_extracto := v_fre_extracto;
     r_garmul.estado := 'G';
     r_garmul.cod_tip_extracto := vg_tip_extracto;
     r_garmul.fec_especifica := v_fecha;
     -- inserta registro multicash
     lp_ins_reg_multicash (r_garmul);
        
     v_mensaje := 'Extracto generado correctamente.';
  ELSE
    v_mensaje := 'Sin Extracto.';
    IF vg_des_errores = 'S' THEN
       raise_application_error(-20000,vg_proceso ||' '|| v_mensaje);
    END IF;
  END IF;  
  vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_programa,vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, v_nro_cuenta || ': ' || v_mensaje );
EXCEPTION
  WHEN OTHERS THEN
    vg_det_error := substr(sqlerrm, 1,800);
    vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub,  v_nro_cuenta || ': ' || substr(vg_det_error, 1, 378));
    IF vg_des_errores = 'S' THEN
       raise_application_error(-20000,vg_proceso ||' '|| vg_det_error);
    END IF;
END;

-- Genera extracto multicash
procedure lp_gen_ext_requerimiento (p_nro_cuenta IN varchar2, p_cod_ente IN number) is
v_linea varchar2(300);
v_mov_monto            ge_movimientos.monto%type;
v_mov_descripcion      ge_movimientos.concepto%type;
v_debitos              ge_ext_cli_movimientos.mto_debito%type;
v_creditos             ge_ext_cli_movimientos.mto_credito%type;
v_deb_requerimiento    ge_ext_cli_movimientos.mto_debito%type;
v_cre_requerimiento    ge_ext_cli_movimientos.mto_credito%type;
v_deb_cabecera         ge_ext_cli_movimientos.mto_debito%type;
v_cre_cabecera         ge_ext_cli_movimientos.mto_credito%type;
v_nro_linea            number;
v_nom_archivo          varchar2(100);
v_fecha                date;
v_cod_extracto         number;
v_sal_anterior         ge_ext_cli_cuentas.sal_anterior%type;
v_nro_cuenta           ge_ext_cli_cuentas.nro_cuenta%type;
v_mto_cabecera         ge_ext_cli_cuentas.sal_actual%type;
v_nom_cliente          ge_ext_clientes.nom_cliente%type;
v_fre_extracto         ge_ext_clientes.fre_extracto%type;
v_exi_extracto         varchar2(1);
v_exi_movimientos      number;
v_cod_mon_iso          ba_monedas.cod_mon_iso%type;
v_cod_persona          ba_personas.cod_persona%type;
v_mensaje              varchar2(100);
r_garmul               ge_arc_multicash_tmp%rowtype;
-- Recupera registros de Extractos ITGF Generados
CURSOR c_extracto(v_nro_cuenta varchar2)  is
-- a requerimiento
select fec_valor, fec_movimiento, mv.fec_insercion, mv.fec_extracto,
   sal_anterior, mto_credito, mto_debito, 
   mv.concepto, descripcion, nro_documento, 
   mv.cod_modulo, mv.cod_modalidad,
   nro_secuencia, hor_movimiento,
   cu.cod_extracto,
   mv.cod_tra_padre,
   c.nom_cliente,
   cu.cod_moneda,
   c.cod_persona,
   c.fre_extracto
from GE_EXT_CLI_MOVIMIENTOS_TMP mv 
  join GE_EXT_CLI_CUENTAS_TMP cu on cu.nro_cuenta = mv.nro_cuenta and mv.fre_extracto=cu.fre_extracto
       and cu.fec_extracto=mv.fec_extracto and cu.cod_extracto=mv.cod_extracto
  join GE_TRANSACCIONES t on t.cod_transaccion = mv.cod_tra_padre and t.cod_modulo = mv.cod_modulo 
       and t.cod_modalidad = mv.cod_modalidad
  join GE_EXT_CLIENTES_TMP c on c.COD_PERSONA=cu.cod_persona and c.FEC_EXTRACTO=cu.FEC_EXTRACTO
     and c.FRE_EXTRACTO=cu.FRE_EXTRACTO and c.COD_EXTRACTO=cu.COD_EXTRACTO
where mv.nro_cuenta = v_nro_cuenta
  and mv.fec_extracto = vg_fec_extracto
  and t.cod_modulo = mv.cod_modulo 
  and t.cod_modalidad = mv.cod_modalidad  
  and mv.fec_extracto = cu.fec_extracto
  and cu.usu_insercion = vg_cod_usuario
union all
-- a requerimiento: sin movimientos
select null fec_valor, vg_fec_especifica fec_movimiento, cu.fec_insercion, cu.fec_extracto,
   cu.sal_anterior, 0 mto_credito, 0 mto_debito, 
   '** Sin Movimientos **' concepto, null descripcion, null nro_documento, 
   null cod_modulo, null cod_modalidad,
   null nro_secuencia, null hor_movimiento,
   cu.cod_extracto,
   null cod_tra_padre,
   null nom_cliente,
   cu.cod_moneda,
   cu.cod_persona,
   cu.fre_extracto
from GE_EXT_CLI_CUENTAS_TMP cu
where vg_sin_movimientos = 'S'
   and cu.fec_extracto = vg_fec_extracto
   and cu.nro_cuenta = v_nro_cuenta
   and cu.usu_insercion = vg_cod_usuario
order by 3;

-- Recupera existencia de cabecera y movimientos en extractos ITGF por cuenta
CURSOR c_exi_movimientos(v_nro_cuenta varchar2)  is
select count(1) movimientos
     from GE_EXT_CLI_CUENTAS_TMP cu
        join GE_EXT_CLI_MOVIMIENTOS_TMP mv on cu.nro_cuenta = mv.nro_cuenta and mv.fre_extracto=cu.fre_extracto
             and cu.fec_extracto=mv.fec_extracto and cu.cod_extracto=mv.cod_extracto
     where mv.nro_cuenta = v_nro_cuenta
        and mv.fec_extracto = vg_fec_extracto
        and mv.fec_extracto = cu.fec_extracto
        and cu.usu_insercion = vg_cod_usuario;
BEGIN
  vg_proceso := 'lp_gen_ext_requerimiento';
  v_nro_cuenta := p_nro_cuenta;
  v_debitos := 0;
  v_creditos := 0;
  v_deb_requerimiento := 0;
  v_cre_requerimiento := 0;
  v_deb_cabecera := 0;
  v_cre_cabecera := 0;
  v_nro_linea := 0;
  v_mto_cabecera := 0;
  vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');
  v_exi_extracto := 'N'; -- no existe extracto
  vg_sin_movimientos := 'N'; --con movimientos
  v_exi_movimientos := 0;
  v_cod_mon_iso := null;
  v_cod_persona := null;
  v_fre_extracto := null;
  
  -- controla existencia de cabecera de extractos y movimientos de la cuenta   
  OPEN c_exi_movimientos(v_nro_cuenta);
  FETCH c_exi_movimientos INTO v_exi_movimientos;
  IF v_exi_movimientos = 0 then
     vg_sin_movimientos := 'S'; -- sin movimientos
  END IF;
  CLOSE c_exi_movimientos;
  
  for reg in c_extracto(v_nro_cuenta) loop
     v_exi_extracto := 'S';
     IF vg_tip_extracto = 'R' THEN
        v_fecha := reg.fec_extracto;
     ELSE
        v_fecha := vg_fec_especifica;
     END IF;
     
     v_mov_descripcion := upper(substr(reg.descripcion,1,vg_lon_descripcion));
     v_cod_extracto := reg.cod_extracto;
     v_sal_anterior := reg.sal_anterior;
     v_nom_cliente := reg.nom_cliente;
     v_cod_mon_iso := reg.cod_moneda;
     v_cod_persona := reg.cod_persona;
     v_fre_extracto := reg.fre_extracto;
     v_nom_archivo := 'UMSATZ_' || v_nro_cuenta || /*'_' ||*/ to_char(v_fecha,'dd-mm-yy') ;
      
     IF vg_tip_extracto = 'R' or ( vg_tip_extracto = 'D' and reg.fec_movimiento = vg_fec_especifica) THEN
       -- adecua monto a partir del extracto
       if reg.mto_debito is not null and reg.mto_debito <> 0 then
          v_mov_monto :=  reg.mto_debito * -1;
       else
          v_mov_monto :=  reg.mto_credito;
       end if;
       -- detalle (UMSATZ.TXT)
       v_linea := vg_cod_banco --1 (A 0 12) codigo de banco
       || vg_separador || v_nro_cuenta        --2 (A 0 24) cuenta
       || vg_separador || v_cod_extracto     --3 (N 1 4) ultimo extracto de la cuenta mas uno
       || vg_separador || to_char( reg.fec_valor, 'dd.mm.yy') --4 (X 8 8) fecha con el formato dd.mm.aa
       || vg_separador --5 (N 1 10)	primary note number [opcional]   
       || vg_separador --6 (A 0 27) note to payee 1 [optional]
       || vg_separador --7 (A 0 27)	bank posting text [opcional]
       || vg_separador --8 (0 0) not used
       || vg_separador || substr(reg.cod_tra_padre,1,4) --9 (A 0 4) text key [opcional]
       || vg_separador || reg.nro_documento --10 (A 0 16) referencia [optional]
       || vg_separador || trim(to_char(v_mov_monto,'999999999999999990.99')) --11 (N 1 18.2) amount
       || vg_separador --12 (0 0) not used
       || vg_separador --13 (0 0) not used
       || vg_separador || to_char( reg.fec_movimiento, 'dd.mm.yy') --14 (8 8) fecha con el formato dd.mm.aa
       || vg_separador --15 (0 0) not used
       || vg_separador --16 (0 0) not used
       || vg_separador || v_mov_descripcion --17 (A 0 27) note to payee 2 [opcional]
       || vg_separador --18 (A 0 27) note to payee 3 [opcional]
       || vg_separador --19 (A 0 27) note to payee 4 [opcional]
       || vg_separador --20 (A 0 27) note to payee 5 [opcional]
       || vg_separador --21 (A 0 27) note to payee 6 [opcional]
       || vg_separador --22 (A 0 27) note to payee 7 [opcional]
       || vg_separador --23 (A 0 27) note to payee 8 [opcional]
       || vg_separador --24 (A 0 27) note to payee 9 [opcional]
       || vg_separador --25 (A 0 27) note to payee 10 [opcional]
       || vg_separador --26 (A 0 27) note to payee 11 [opcional]
       || vg_separador --27 (A 0 27) note to payee 12 [opcional]
       || vg_separador --28 (A 0 27) note to payee 13 [opcional]
       || vg_separador --29 (A 0 27) note to payee 14 [opcional]
       || vg_separador --30 (A 0 27) business partner [opcional]
       || vg_separador --31 (A 0 27) business partner [opcional]
       || vg_separador --32 (A 0 12) bank key of the partner's bank [opcional]
       || vg_separador --33 (A 0 24) bank account number of the partner [opcional]
       || vg_separador || substr(reg.cod_tra_padre,1,3) --34 (A 0 3)  business transaction code [opcional]
       ;
       -- genera la linea si hay movimientos reales
       IF vg_sin_movimientos = 'N' THEN
          v_nro_linea := v_nro_linea + 1;
         
          r_garmul.nro_linea := v_nro_linea;
          r_garmul.texto := v_linea;
          r_garmul.cod_extracto := v_cod_extracto;
          r_garmul.nro_cuenta := v_nro_cuenta;
          r_garmul.nom_archivo := v_nom_archivo;
          r_garmul.fec_extracto := vg_fec_extracto;
          r_garmul.cod_ente := p_cod_ente;
          r_garmul.cod_persona := v_cod_persona;
          r_garmul.fre_extracto := v_fre_extracto;
          r_garmul.estado := 'G';
          r_garmul.cod_tip_extracto := vg_tip_extracto;
          r_garmul.fec_especifica := v_fecha;
          -- inserta registro multicash
          lp_ins_reg_multicash (r_garmul);
       END IF;
     END IF;
     
     -- acumula datos para cabecera (AUSZUG.TXT)
     IF vg_tip_extracto = 'R' or ( vg_tip_extracto = 'D' and reg.fec_movimiento <= vg_fec_especifica) THEN
       v_creditos := v_creditos + reg.mto_credito;
       v_debitos := v_debitos + reg.mto_debito;
       -- acumula debitos y creditos del dia a requerimiento
       IF vg_tip_extracto = 'D' and reg.fec_movimiento = vg_fec_especifica THEN
          v_cre_requerimiento := v_cre_requerimiento + reg.mto_credito;
          v_deb_requerimiento := v_deb_requerimiento + reg.mto_debito;
       END IF;
     END IF;  
  end loop;
  
  IF v_exi_extracto = 'S' THEN
    -- cabecera (AUSZUG.TXT)
    v_nom_archivo := 'AUSZUG_' || v_nro_cuenta || /*'_' ||*/ to_char(v_fecha,'dd-mm-yy');
    v_mto_cabecera := v_sal_anterior - v_debitos + v_creditos;
    
    IF vg_tip_extracto = 'R' THEN
       v_deb_cabecera := v_debitos;
       v_cre_cabecera := v_creditos;
    ELSE
       v_deb_cabecera := v_deb_requerimiento;
       v_cre_cabecera := v_cre_requerimiento;
       v_sal_anterior := v_sal_anterior - (v_debitos - v_deb_requerimiento) + (v_creditos-v_cre_requerimiento);
    END IF;
    
    -- recupera codigo iso de la moneda de la cuenta
    v_cod_mon_iso := lf_obt_mon_iso (v_cod_mon_iso);
    
    v_linea := vg_cod_banco --1 codigo de banco(A 0 12 bank key)
       || vg_separador || v_nro_cuenta --2 cuenta (A 0 24)
       || vg_separador || v_cod_extracto --3 (N 1 4) ultimo extraco de cuenta).append(1
       || vg_separador || to_char(v_fecha,'dd.mm.yy') --4 (X 8 8) fecha con formato dd.mm.aa
       || vg_separador || v_cod_mon_iso --5 (A 3 3) currency key
       || vg_separador || trim(to_char(v_sal_anterior,'999999999999999990.99')) --6 N 1 18.2 opening balance amount
       || vg_separador || trim(to_char(v_deb_cabecera,'999999999999999990.99')) --7 (N 1 18.2) debit total
       || vg_separador || trim(to_char(v_cre_cabecera,'999999999999999990.99')) --8 (N 1 18.2) credit total
       || vg_separador || trim(to_char(v_mto_cabecera,'999999999999999990.99')) --9 (N 1 18.2) closing balance amount
       || vg_separador || substr(v_nom_cliente, 1, 35) --10 (A 0 35) bank account holder
       || vg_separador --11 (A 0 35) special account name [opcional]
       || vg_separador --12 (X 8 8) life start [opcional]
       || vg_separador --13 (X 8 8) life end [opcional]
       || vg_separador --14 0 0 not used
       || vg_separador --15 0 0 not used
       || vg_separador --16 0 0 not used
       || vg_separador --17 0 0 not used
       || vg_separador || v_nro_linea --18 N 1 5 number of records in statement
       ;
    r_garmul.nro_linea := 0;
    r_garmul.texto := v_linea;
    r_garmul.cod_extracto := v_cod_extracto;
    r_garmul.nro_cuenta := v_nro_cuenta;
    r_garmul.nom_archivo := v_nom_archivo;
    r_garmul.fec_extracto := vg_fec_extracto;
    r_garmul.cod_ente := p_cod_ente;
    r_garmul.cod_persona := v_cod_persona;
    r_garmul.fre_extracto := v_fre_extracto;
    r_garmul.estado := 'G';
    r_garmul.cod_tip_extracto := vg_tip_extracto;
    r_garmul.fec_especifica := v_fecha;
    -- inserta registro multicash
    lp_ins_reg_multicash (r_garmul);
    v_mensaje := 'Extracto generado correctamente.';
  ELSE
    v_mensaje := 'Sin Extracto.';
    IF vg_des_errores = 'S' THEN
       raise_application_error(-20000,vg_proceso ||' '|| v_mensaje);
    END IF;
  END IF;  
  vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_programa,vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, v_nro_cuenta || ': ' || v_mensaje );
EXCEPTION
  WHEN OTHERS THEN
    vg_det_error := substr(sqlerrm, 1,800);
    vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub,  v_nro_cuenta || ': ' || substr(vg_det_error, 1, 378));
    IF vg_des_errores = 'S' THEN
       raise_application_error(-20000,vg_proceso ||' '|| vg_det_error);
    END IF;
END;

-- Actualiza Estado de Cabecera de Archivo
procedure lp_act_estado(p_cod_persona IN varchar2,
                        p_fec_extracto IN date,
                        p_cod_extracto IN number,
                        p_fre_extracto IN varchar2,
                        p_nro_cuenta IN varchar2,
                        p_cod_tip_extracto IN varchar2,
                        p_det_error IN varchar2 default NULL ) is
v_det_error varchar2(300);
v_estado varchar2(1);
BEGIN
   IF p_det_error is not null THEN
      v_det_error := substr(p_det_error,1,300);
      v_estado := 'F'; -- marca con error
   ELSE
      v_det_error := NULL;
      v_estado := 'E'; -- marca como enviado
   END IF;
   update GE_ARC_MULTICASH_TMP t 
      set estado = v_estado,
      det_error = v_det_error,
      cod_can_envio = vg_can_envio
   where  cod_persona = p_cod_persona
      and fec_extracto = p_fec_extracto
      and cod_extracto = p_cod_extracto
      and fre_extracto = p_fre_extracto
      and nro_cuenta = p_nro_cuenta
      and cod_tip_extracto = p_cod_tip_extracto
      and nro_linea = 0
      and nom_archivo is NOT NULL;-- no recupera registros de solo aviso de error
END;

-- Envia email por cuenta
procedure lp_gen_env_email(p_nro_cuenta IN varchar2, p_dir_email IN varchar2) is
v_conexion   utl_smtp.connection;
v_dir_para           varchar2(100);
v_dir_de             varchar2(100);
v_asunto             varchar2(100);
v_contenido          varchar2(100);
v_detalle            varchar2(4000);
v_nom_archivo        varchar2(100);
v_nro_cuenta         ge_ext_cli_cuentas.nro_cuenta%type;
v_fec_archivo        date;

BEGIN
   if (vg_tip_extracto = 'M' or vg_tip_extracto = 'R') then
     v_fec_archivo := vg_fec_extracto;
   else
     v_fec_archivo := nvl(vg_fec_especifica, vg_fec_extracto);
   end if;
   
   vg_det_error := '';
   vg_proceso := 'lp_gen_env_email';
   v_nro_cuenta := p_nro_cuenta;
   v_dir_para := p_dir_email;
   v_dir_de  := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com.py';
   v_asunto  := 'Extracto Cuenta ' || v_nro_cuenta || ' - ' || to_char(v_fec_archivo,'DD-MM-YY');
   v_contenido  := 'Adjunto archivos del extracto.' || chr(10);
   v_detalle := '';
   vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');  
   v_nom_archivo := null;
   v_conexion := it_mail.begin_mail(v_dir_de, v_dir_para, v_asunto, IT_MAIL.MULTIPART_MIME_TYPE);
   it_mail.attach_text(v_conexion, v_contenido, 'text/plain');
   for linea in c_contenido(v_nro_cuenta) loop
     if v_nom_archivo is null or nvl(v_nom_archivo,'') != linea.nom_archivo then 
        if v_nom_archivo is not null then
           UTL_SMTP.WRITE_DATA(v_conexion, UTL_TCP.CRLF);
        end if;
        
        it_mail.begin_attachment(v_conexion, 'text/plain', false, linea.nom_archivo || vg_ext_archivo);
        v_nom_archivo := linea.nom_archivo;
     end if;        
     v_detalle := linea.texto || chr(13) || chr(10);
     it_mail.write_text(v_conexion, v_detalle);
     
   end loop;
   UTL_SMTP.WRITE_DATA(v_conexion, UTL_TCP.CRLF);
   it_mail.end_mail(v_conexion);
   -- marca envio
   lp_act_estado(vg_pk_cod_persona, vg_fec_extracto, vg_pk_cod_extracto,
                        vg_pk_fre_extracto, vg_pk_nro_cuenta, vg_tip_extracto);
   vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub,  v_nro_cuenta || ': email enviado correctamente.');
EXCEPTION
   WHEN utl_smtp.transient_error or utl_smtp.permanent_error THEN
      vg_det_error := substr(sqlerrm,1,400);
      -- marca con error
      lp_act_estado(vg_pk_cod_persona, vg_fec_extracto, vg_pk_cod_extracto,
                    vg_pk_fre_extracto, vg_pk_nro_cuenta, vg_tip_extracto, 
                    vg_det_error);
      begin
        utl_smtp.quit(v_conexion);
      exception
        when others then
          vg_det_error := vg_det_error || substr(sqlerrm,1,400);
      end;
      vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub,  v_nro_cuenta || ': ' || substr(vg_det_error, 1, 378));
      IF vg_des_errores = 'S' THEN
         raise_application_error(-20000,vg_proceso ||' '|| vg_det_error);
      END IF;
   WHEN OTHERS THEN
      vg_det_error := substr(sqlerrm,1,400);
      -- marca con error
      lp_act_estado(vg_pk_cod_persona, vg_fec_extracto, vg_pk_cod_extracto,
                    vg_pk_fre_extracto, vg_pk_nro_cuenta, vg_tip_extracto, 
                    vg_det_error);
      begin
        utl_smtp.quit(v_conexion);
      exception
        when others then
          vg_det_error := vg_det_error || substr(sqlerrm,1,400);
      end;
      vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub,  v_nro_cuenta || ': ' || substr(vg_det_error, 1, 378));
      IF vg_des_errores = 'S' THEN
         raise_application_error(-20000,vg_proceso ||' '|| vg_det_error);
      END IF;
END;

-- Envia archivo via ftp
procedure lp_env_ftp(p_nom_archivo IN varchar2, 
                     p_ftp_dir_repositorio IN varchar2, 
                     p_ftp_dir_ip IN varchar2, 
                     p_ftp_dir_puerto IN varchar2, 
                     p_ftp_usuario IN varchar2, 
                     p_ftp_contrasena IN varchar2) is
  v_conexion      UTL_TCP.connection;
BEGIN
  vg_proceso := 'lp_env_ftp';
  vg_det_error := null;
  v_conexion := utl_ftp.login(p_ftp_dir_ip, p_ftp_dir_puerto, p_ftp_usuario, p_ftp_contrasena); -- datos del cliente!
  utl_ftp.binary(p_conn => v_conexion);
  utl_ftp.put(p_conn      => v_conexion,
              p_from_dir  => vg_dir_servidor, --carpeta servidor
              p_from_file => p_nom_archivo || vg_ext_archivo,
              p_to_file   => p_ftp_dir_repositorio || p_nom_archivo || vg_ext_archivo --dir remoto
              );
  utl_ftp.logout(v_conexion);
  UTL_TCP.close_all_connections;
EXCEPTION
  WHEN OTHERS THEN
    vg_det_error := substr(sqlerrm,1,400);
    begin
      UTL_TCP.close_connection(v_conexion);
    exception
      when others then
        vg_det_error := vg_det_error || substr(sqlerrm,1,400);
    end;
    IF vg_des_errores = 'S' THEN
       raise_application_error(-20000,vg_proceso ||' '|| vg_det_error);
    END IF;
END;

-- Genera y envia archivos por cuenta
procedure lp_gen_archivos (p_nro_cuenta IN varchar2) is
v_archivo       utl_file.file_type;
v_nom_archivo   varchar2(100);
v_nro_cuenta    ge_ext_cli_cuentas.nro_cuenta%type;
begin
  v_nom_archivo := null;
  v_nro_cuenta  := p_nro_cuenta;
  vg_proceso := 'lp_gen_archivos';
  vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');
  for linea in c_contenido(v_nro_cuenta) loop
     if v_nom_archivo is null or nvl(v_nom_archivo,'') != linea.nom_archivo then 
        if v_nom_archivo is not null then
           utl_file.fclose(v_archivo);
        end if;
        v_nom_archivo := linea.nom_archivo;
        v_archivo     := utl_file.fopen(vg_dir_servidor, v_nom_archivo || vg_ext_archivo, 'W', 32767);
     end if;
     utl_file.put_line(v_archivo, linea.texto || chr(13) || chr(10));     
  end loop;
  utl_file.fclose(v_archivo);
  vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, v_nro_cuenta || ': extractos generados y enviados con exito.');
exception
  when others then
     vg_det_error := substr(sqlerrm,1,400);
     -- marca con error
     lp_act_estado(vg_pk_cod_persona, vg_fec_extracto, vg_pk_cod_extracto,
                   vg_pk_fre_extracto, vg_pk_nro_cuenta, vg_tip_extracto, 
     	             vg_det_error);
     vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
     prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, v_nro_cuenta || ': ' || substr(vg_det_error, 1, 378));
     IF vg_des_errores = 'S' THEN
        raise_application_error(-20000,vg_proceso ||' '|| vg_det_error);
     END IF;
end;

-- Envia archivos por FTP
procedure lp_env_archivos(p_nro_cuenta IN varchar2, 
                          p_ftp_dir_repositorio IN varchar2, 
                          p_ftp_dir_ip IN varchar2, 
                          p_ftp_dir_puerto IN varchar2, 
                          p_ftp_usuario IN varchar2, 
                          p_ftp_contrasena IN varchar2) is
v_nom_archivo   varchar2(100);
v_nro_cuenta    ge_ext_cli_cuentas.nro_cuenta%type;

-- Recupera el nombre de los archivos generados de una cuenta especifica
CURSOR c_archivos(v_nro_cuenta varchar2) is
   select distinct a.nom_archivo
   from ge_arc_multicash_tmp a
   where a.nro_cuenta = v_nro_cuenta
      and ((a.fec_extracto = vg_fec_extracto and vg_tip_extracto IN ('M','R')) or
          (a.fec_especifica = vg_fec_especifica and vg_tip_extracto = 'D'))
      and decode(vg_tip_extracto, 'D', a.usu_insercion, 'R', a.usu_insercion, vg_cod_usuario) = vg_cod_usuario
      and a.cod_tip_extracto = vg_tip_extracto
      and a.fec_extracto = vg_fec_extracto
      and a.nom_archivo is NOT NULL -- no recupera registros de solo aviso de error
   order by a.nom_archivo;
begin
  v_nom_archivo := null;
  v_nro_cuenta  := p_nro_cuenta;
  vg_proceso := 'lp_gen_archivos';
  vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');
  for arc in c_archivos(v_nro_cuenta) loop
     v_nom_archivo := arc.nom_archivo;

     lp_env_ftp(v_nom_archivo,
         p_ftp_dir_repositorio,
         p_ftp_dir_ip,
         p_ftp_dir_puerto,
         p_ftp_usuario,
         p_ftp_contrasena);
         
     if vg_det_error is not null then
        Raise_Application_Error(-20000, vg_det_error);
     end if;  
  end loop;
  if vg_det_error is not null then
     Raise_Application_Error(-20000, vg_det_error);
  end if;
  -- marca envio
  lp_act_estado(vg_pk_cod_persona, vg_fec_extracto, vg_pk_cod_extracto,
                vg_pk_fre_extracto, vg_pk_nro_cuenta, vg_tip_extracto);
  vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, v_nro_cuenta || ': extractos generados y enviados con exito.');
exception
  when others then
     vg_det_error := substr(sqlerrm,1,400); 
     -- marca con error
     lp_act_estado(vg_pk_cod_persona, vg_fec_extracto, vg_pk_cod_extracto,
                   vg_pk_fre_extracto, vg_pk_nro_cuenta, vg_tip_extracto, 
                   vg_det_error);
     vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
     prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, v_nro_cuenta || ': ' || substr(vg_det_error, 1, 378));
     IF vg_des_errores = 'S' THEN
        raise_application_error(-20000,vg_proceso ||' '|| vg_det_error);
     END IF;
end;

-- Elimina acentos
FUNCTION lf_eli_acentos (p_cadena VARCHAR2) 
  RETURN VARCHAR2 IS
v_cadena VARCHAR2(4000);
BEGIN
  IF p_cadena IS NOT NULL THEN
     v_cadena := translate(p_cadena,
              'áéíóúàèìòùäëïöüÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ,+´~|°ºª¬!"#$%&/()=?¡¿*¨{}^`¿[]:;><Çç%',
              'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
     v_cadena := translate(v_cadena,
              'âêîôûÂÊÎÔÛÃãÐÕ×ØÝÞßåæðõø÷ýþÿAa\¢£¤¥¦§©«®¯±²³µ¶·¸¹º»¼½¾¿',
              'aeiouAEIOUAaDO     a  o  y yAa                           ');
     v_cadena := translate(v_cadena,
              '''',
              '  ');
  END IF;
  RETURN(v_cadena);
END;

-- Valida direccion de email
Function lf_val_correo (p_mail VARCHAR2) 
  RETURN VARCHAR2 IS
v_mail         VARCHAR2(319) := lower(p_mail);
v_nom_usuario  VARCHAR2(64);
v_nom_dominio  VARCHAR2(254);
v_caracter     VARCHAR2(1);
v_posicion     NUMBER(3);
v_car_invalido NUMBER(3);
v_con_caracter NUMBER(3) := 0;
v_pos_coma     NUMBER(3);
v_pos_punto    NUMBER(3);
 BEGIN
    --- Identificar el primer correo
    v_pos_punto    := instr(v_mail, ';'); -- hasta el punto y coma
    v_pos_coma     := instr(v_mail, ','); -- hasta la coma
    IF v_pos_punto = 0 and v_pos_coma = 0 THEN
       v_posicion := length(v_mail);
    ELSIF v_pos_coma = 0 THEN
       v_posicion := v_pos_punto - 1;
    ELSIF v_pos_punto = 0 THEN
       v_posicion := v_pos_coma - 1;
    ELSIF v_pos_coma > v_pos_punto THEN
       v_posicion := v_pos_punto - 1;
    ELSIF v_pos_punto > v_pos_coma THEN
       v_posicion := v_pos_coma - 1;
    ELSE -- Contiene solo 1 correo
       v_posicion := length(v_mail);
    END IF;
    v_mail := substr(v_mail, 1, v_posicion);
    --
    v_posicion    := instr(v_mail, '@');
    v_nom_usuario := substr(v_mail, 1, instr(v_mail, '@') - 1);
    v_nom_dominio := substr(v_mail, instr(v_mail, '@') + 1);
    ---
    /*
    || Dominios Genéricos
    || ==================
    || .com .net .org
    || .mil .gov .edu .int .coop
    || .info .biz
    || .mobi
    */
    IF instr(v_nom_dominio,'.com',1) > 0 OR
       instr(v_nom_dominio,'.net',1) > 0 OR
       instr(v_nom_dominio,'.org',1) > 0 OR
       instr(v_nom_dominio,'.mil',1) > 0 OR
       instr(v_nom_dominio,'.gov',1) > 0 OR
       instr(v_nom_dominio,'.edu',1) > 0 OR
       instr(v_nom_dominio,'.int',1) > 0 OR
       instr(v_nom_dominio,'.biz',1) > 0 OR
       instr(v_nom_dominio,'.coop',1) > 0 OR
       instr(v_nom_dominio,'.info',1) > 0 OR
       instr(v_nom_dominio,'.mobi',1) > 0 THEN
       null;
    ELSE
       return null;
    END IF;
    v_mail := lf_eli_acentos(v_mail);
    ---
    FOR i IN 1 .. length(v_mail) LOOP
       v_caracter := substr(v_mail, i, 1);
       IF v_caracter = '@' THEN
          v_con_caracter := v_con_caracter + 1;
       END IF;
    END LOOP;
    ---
    IF v_posicion <= 1 OR
       v_posicion = length(v_mail) OR
       v_con_caracter > 1 THEN
       return null;
    ELSIF substr(v_nom_usuario, 1, 1) = '.' OR
          substr(v_nom_usuario, length(v_nom_usuario), 1) = '.' THEN
       return null;
    ELSIF substr(v_nom_dominio, 1, 1) = '.' OR
          substr(v_nom_dominio, length(v_nom_dominio), 1) = '.' OR
          instr(v_nom_dominio, '.') = 0 THEN
       return null;
    ELSIF v_car_invalido > 0 THEN
       return null;
    ELSIF instr(v_mail, '..') > 0 THEN
       return null;
    ELSIF length(v_nom_usuario) > 64 THEN
       return null;
    ELSIF length(v_nom_dominio) > 255 THEN
       return null;
    END IF;
    RETURN v_mail;
 END;
 
-- Envia archivos multicash
procedure lp_env_extractos (p_nro_cuenta IN varchar2, p_cod_ente number) is
v_can_envio          ge_par_entes.val_parametro%type;
v_dir_email          ge_par_entes.val_parametro%type;
v_ftp_dir_repositorio ge_par_entes.val_parametro%type;
v_ftp_dir_ip          ge_par_entes.val_parametro%type;
v_ftp_dir_puerto      ge_par_entes.val_parametro%type;
v_ftp_usuario         ge_par_entes.val_parametro%type;
v_ftp_contrasena      ge_par_entes.val_parametro%type;
v_mensaje             varchar2(100);
BEGIN
   vg_proceso := 'lp_env_extractos';
   vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');
   vg_det_error := NULL;
   -- recupera parametros para el envio  
   v_can_envio := fug_obt_parentes(p_cod_ente,'MUL_CAN_ENV_ARCHIVO'); -- canal de envio
   v_dir_email := fug_obt_parentes(p_cod_ente,'MUL_DIR_ENV_MAIL'); -- email
   v_ftp_dir_repositorio := fug_obt_parentes(p_cod_ente,'MUL_FTP_DIR_CARPETA');
   v_ftp_dir_ip := fug_obt_parentes(p_cod_ente,'MUL_FTP_DIR_IP');
   v_ftp_dir_puerto := fug_obt_parentes(p_cod_ente,'MUL_FTP_DIR_PUERTO');
   v_ftp_usuario := fug_obt_parentes(p_cod_ente,'MUL_FTP_ENV_USUARIO'); 
   v_ftp_contrasena := fug_obt_parentes(p_cod_ente,'MUL_FTP_ENV_CLAVE');
   vg_nro_cuenta := p_nro_cuenta;
   v_mensaje := 'ok';
   vg_can_envio := v_can_envio;
   
   if v_can_envio = 'M' then -- Envio por Email
      if lf_val_correo(v_dir_email) is not null then
        -- envia por email
        lp_gen_env_email(p_nro_cuenta, v_dir_email);
      else
        v_mensaje := 'direccion email invalida ' || v_dir_email;
        -- marca con error
        lp_act_estado(vg_pk_cod_persona, vg_fec_extracto, vg_pk_cod_extracto,
                      vg_pk_fre_extracto, vg_pk_nro_cuenta, vg_tip_extracto, 
                      v_mensaje);
        IF vg_des_errores = 'S' THEN
           raise_application_error(-20000,vg_proceso ||' '|| v_mensaje);
        END IF;
      end if;
   else -- Envio por FTP
      if v_ftp_dir_repositorio is not null and
         v_ftp_dir_ip is not null and
         v_ftp_dir_puerto is not null and
         v_ftp_usuario is not null and
         v_ftp_contrasena is not null then
         
          -- genera archivos txt
          lp_gen_archivos( p_nro_cuenta);
          
          IF vg_det_error IS NULL THEN
            -- envia archivos por ftp
            lp_env_archivos( p_nro_cuenta,
                            v_ftp_dir_repositorio,
                            v_ftp_dir_ip,
                            v_ftp_dir_puerto,
                            v_ftp_usuario,
                            v_ftp_contrasena);
          END IF;
       else
          v_mensaje := 'faltan parametros para envio ftp ' ;
          -- marca con error
          lp_act_estado(vg_pk_cod_persona, vg_fec_extracto, vg_pk_cod_extracto,
                        vg_pk_fre_extracto, vg_pk_nro_cuenta, vg_tip_extracto, 
                        v_mensaje);
          IF vg_des_errores = 'S' THEN
             raise_application_error(-20000,vg_proceso ||' '|| v_mensaje);
          END IF;
       end if;
   end if;
   vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, p_nro_cuenta || ': ' || v_mensaje);
END;   
   
-- Trunca tablas tmp del proceso
PROCEDURE lp_tru_tab_temporales is
   v_msj     VARCHAR2(200);
   v_sql     VARCHAR2(200);
BEGIN
   vg_proceso := 'lp_tru_tab_temporales';
   vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');
   IF vg_tip_extracto = 'D' or vg_tip_extracto = 'R' THEN
      v_sql := 'delete from ge_arc_multicash_tmp where usu_insercion = ''' || vg_cod_usuario ||'''';
      sql_util.ejecute_dml(v_sql, v_msj);
   ELSE
      v_sql := 'truncate table ge_arc_multicash_tmp';
      sql_util.ejecute_dml(v_sql, v_msj);
   END IF;
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20000, v_msj);
   END IF; 
   vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, null);
END;

-- Genera Extracto Multicash
PROCEDURE lp_gen_ext_multicash is
  r_garmul               ge_arc_multicash_tmp%rowtype; 
BEGIN
  vg_proceso := 'lp_gen_ext_multicash';
  vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');
  for ente in c_ente loop
     for cuentas in c_cuentas(ente.str_cuentas) loop
        if lf_val_cta_persona(ente.cod_persona,cuentas.nro_cuenta) = 'S' then
           if vg_tip_extracto = 'M' then
              lp_gen_ext_mensual(cuentas.nro_cuenta, ente.cod_ente);
           else
              -- genera el extracto a requerimiento ITGF
              IF (vg_tip_extracto = 'R' or vg_tip_extracto = 'D') then
                 prg_gen_extracto_tmp(ente.cod_persona,
                                      cuentas.nro_cuenta);
                 IF vg_fec_extracto IS NULL THEN
                    -- establece vg_fec_extracto
                    BEGIN
                      select max(t.fec_extracto)
                          into vg_fec_extracto
                      from GE_EXT_CLI_CUENTAS_TMP t 
                      where nvl(vg_nro_cuenta, t.nro_cuenta)=t.nro_cuenta
                          and t.usu_insercion = vg_cod_usuario;
                      -- si es tipo 'R' se establece fecha a requerimiento igual a fecha extracto
                      IF vg_tip_extracto = 'R' THEN
                         vg_fec_especifica := vg_fec_extracto;
                      END IF;
                    EXCEPTION
                          WHEN others THEN
                              raise_application_error(-20000,vg_proceso ||' '|| sqlerrm);
                    END;
                 END IF;
              END IF;
              lp_gen_ext_requerimiento(cuentas.nro_cuenta, ente.cod_ente);
           end if;
         else
            -- la cuenta no corresponde a la persona
            IF vg_des_errores = 'S' THEN
               raise_application_error(-20000, vg_proceso ||' '|| 
                 'La cuenta ' || cuentas.nro_cuenta ||
                 ' no pertenece a la persona ' || ente.cod_persona ||
                 '. Codigo Ente: ' || ente.cod_ente);
            END IF;
            -- se registra el error
            r_garmul.nro_linea := 0;
            r_garmul.texto := null;
            r_garmul.cod_extracto := 0;
            r_garmul.nro_cuenta := cuentas.nro_cuenta;
            r_garmul.nom_archivo := null;
            r_garmul.fec_extracto := nvl(vg_fec_extracto,trunc(sysdate));
            r_garmul.cod_ente := ente.cod_ente;
            r_garmul.cod_persona := ente.cod_persona;
            r_garmul.fre_extracto := 'X';
            r_garmul.estado := 'F';
            r_garmul.cod_tip_extracto := vg_tip_extracto;
            r_garmul.fec_especifica := trunc(sysdate);
            r_garmul.det_error := 'La cuenta ' || cuentas.nro_cuenta ||
               ' no pertenece a la persona ' || ente.cod_persona ||
               '. Codigo Ente: ' || ente.cod_ente;
            -- inserta registro multicash
            lp_ins_reg_multicash (r_garmul);
        end if;
      end loop;
  end loop;
  vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, null);
END;

-- Envia Extracto Multicash
PROCEDURE lp_env_ext_multicash is
-- Cursor de Extractos Multicash Generados en el procesamiento         
CURSOR c_ext_generados is
   select distinct a.nro_cuenta, a.cod_ente, 
          a.cod_persona, a.cod_extracto, a.fre_extracto
   from ge_arc_multicash_tmp a
        where ((a.fec_extracto = vg_fec_extracto and vg_tip_extracto IN ('M','R')) or
              (a.fec_especifica = vg_fec_especifica and vg_tip_extracto = 'D'))
        and a.cod_tip_extracto = vg_tip_extracto
        and a.fec_extracto = vg_fec_extracto
        and a.nro_linea = 0 -- solo recupera cabeceras de extractos
        and decode(vg_tip_extracto, 'D', a.usu_insercion, 'R', a.usu_insercion, vg_cod_usuario) = vg_cod_usuario
        and estado IN ('G', 'F') -- Generados y con Falla de envio
        and a.nom_archivo is NOT NULL -- no recupera registros de solo aviso de error
        ; 
BEGIN
  vg_proceso := 'lp_env_ext_multicash';
  vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');
  for ext in c_ext_generados loop
     vg_pk_cod_persona := ext.cod_persona;
     vg_pk_cod_extracto := ext.cod_extracto;
     vg_pk_fre_extracto := ext.fre_extracto;
     vg_pk_nro_cuenta := ext.nro_cuenta;
     
     lp_env_extractos(ext.nro_cuenta, ext.cod_ente);
  end loop;
  vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, null);
END;

-- Envia Email de Alerta
PROCEDURE lp_env_ema_alerta(p_texto in varchar2) IS
  v_para       VARCHAR2(4000);
  -- Variables para mail
  v_asunto     VARCHAR2(2000);
  v_texto LONG;
  v_hin_mail ge_ra_log_mail.hor_inicio%type;
  v_hfi_mail ge_ra_log_mail.hor_fin%type;
  v_det_error ge_ra_log_mail.det_error%type;
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   vg_proceso := 'lp_env_ema_alerta';
   v_asunto := 'Generación y Envío de Archivos Multicash';
   v_texto := 'Usuario: ' || vg_cod_usuario || chr(10) ||
              'Proceso: ' || vg_programa || chr(10) ||
              'Hora Inicio: ' || vg_hor_inicio || chr(10) || p_texto;
   BEGIN
      v_hin_mail := to_char(sysdate, 'hh24:mi:ss');
      v_para := fug_obt_pardinamico('ENV_EMA_ERR_MUL');
      it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'), v_para, v_asunto, v_texto);
      v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');
   EXCEPTION
      when others then
         v_det_error := substr(sqlerrm, 1, 4000);
         INSERT INTO ge_ra_log_mail (fec_envio, nom_archivo, dir_correo, mensaje,
            det_error, hor_inicio, hor_fin)
         VALUES (SYSDATE, null, v_para, v_asunto,
            v_det_error, v_hin_mail, v_hfi_mail);
   END;
   commit;
   vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, null);
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;

-- Verifica Detalles de Procesamiento y Envia Detalle por email
PROCEDURE lp_ver_det_procesamiento is
-- Cursor de Archivos Generados en el procesamiento         
CURSOR c_arc_generados is
   select distinct a.nro_cuenta, a.cod_ente, 
          a.cod_persona, a.estado, a.det_error
   from ge_arc_multicash_tmp a
        where ((a.fec_extracto = vg_fec_extracto and vg_tip_extracto IN ('M','R')) or
              (a.fec_especifica = vg_fec_especifica and vg_tip_extracto = 'D'))
        and a.cod_tip_extracto = vg_tip_extracto
        and a.fec_extracto = vg_fec_extracto
        and a.nro_linea = 0 -- solo recupera cabeceras de extractos
        and decode(vg_tip_extracto, 'D', a.usu_insercion, 'R', a.usu_insercion, vg_cod_usuario) = vg_cod_usuario;
   v_con_enviados number;
   v_con_errores  number;
   v_con_otros    number;
   v_det_errores  varchar2(4000);
   v_mensaje      varchar2(4000);
BEGIN
  -- verifica solo envios masivos
  IF vg_des_errores = 'N' THEN
    vg_proceso := 'lp_ver_det_procesamiento';
    vg_hor_ini_sub := to_char(sysdate,'hh24:mi:ss');
    v_con_enviados := 0;
    v_con_errores := 0;
    v_con_otros := 0;
    v_det_errores := '';
    for arc in c_arc_generados loop
       IF arc.estado = 'F' THEN -- F - Fallo (Error)
          v_con_errores := v_con_errores + 1;
          v_det_errores := v_det_errores || 
             'Cuenta: ' || arc.nro_cuenta || 
             ' Persona: ' || arc.cod_persona ||
             ' Ente: ' || arc.cod_ente || chr(10) || 
             'Error: ' || arc.det_error || chr(10) || '---' || chr(10);
       ELSIF arc.estado = 'E' THEN -- E - Enviado
          v_con_enviados := v_con_enviados + 1;
       ELSE
          v_con_otros := v_con_otros + 1;
       END IF;
    end loop;
    -- solo envia email si hay errores
    IF v_con_errores > 0 THEN
      v_mensaje := 'Enviados: ' || v_con_enviados || chr(10) ||
               'Errores: ' || v_con_errores || chr(10) ||
               'Otros: ' || v_con_otros || chr(10) || 
               'Detalle: ' || chr(10) || v_det_errores;
      -- envia email de alerta         
      lp_env_ema_alerta(v_mensaje);
    END IF; 
    vg_hor_fin_sub := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_programa, vg_proceso, vg_fec_actual, vg_hor_ini_sub, vg_hor_fin_sub, null);
  END IF;
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;

BEGIN
  vg_programa := 'prg_pro_arc_mul';
  vg_proceso  := '';
  vg_hor_inicio:= to_char(sysdate,'hh24:mi:ss');

  -- inicializa variables del proceso
  lp_ini_variables;
  
  IF nvl(vg_tip_procesamiento, 'G') = 'G' THEN
    -- controla existencia extractos
    lp_val_extractos;
  END IF;

  IF nvl(vg_tip_procesamiento, 'G') = 'G' THEN
    -- borra tabla archivos
    lp_tru_tab_temporales;
  END IF;

  IF nvl(vg_tip_procesamiento, 'G') = 'G' THEN 
    -- formateo de extractos
    lp_gen_ext_multicash;
  END IF;
  
  IF nvl(vg_tip_procesamiento, 'E') = 'E' THEN
    -- envio de extractos
    lp_env_ext_multicash;
    
    -- verifica envios masivos, envia email en caso de error
    lp_ver_det_procesamiento;
  END IF;
  
  vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_programa, vg_programa, vg_fec_actual, vg_hor_inicio, vg_hor_fin, 'Tipo: ' || vg_tip_extracto ||', Tip_proc: ' || vg_tip_procesamiento || ' - ' || p_nro_cuenta ||' Proceso finalizado.');
EXCEPTION
  WHEN OTHERS THEN
     vg_det_error := substr(sqlerrm, 1,800);
     vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
     prg_act_log_procesos(vg_programa, vg_programa, vg_fec_actual, vg_hor_inicio, vg_hor_fin, 'Tipo: ' || vg_tip_extracto ||', Tip_proc: ' || vg_tip_procesamiento || ' - ' || p_nro_cuenta || ' Error: ' || vg_det_error);
     raise_application_error(-20000,'prg_gen_arc_multicash '|| vg_det_error);
END prg_pro_arc_mul;
/

