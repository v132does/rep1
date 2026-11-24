CREATE OR REPLACE PROCEDURE IT.PRG_GEN_MSJ_MT940 (p_cod_banco  IN number default null,
                                               p_fecha      IN date default null,
                                               p_nro_cuenta IN varchar2 default null) -- DYDMR3877-OMM Se agrega Nro_Cuenta para generar por cada cuenta
 IS
  v_texto        varchar2(2000) := null;
  v_fec_actual   varchar2(6);-- := to_char(pae_cnf.fu_obt_fec_actual(4),'yymmdd');
  v_fec_anterior date := fug_obt_fec_anterior(4);
  v_fec_ant_chr  varchar2(6) := to_char(v_fec_anterior,'yymmdd');
  v_mascara      varchar2(15);
  v_detalle      varchar2(1);
  v_cod_moneda   varchar2(3);
  v_tip_saldo    varchar2(1); -- Tipo DÈbito/CrÈdito
  v_tip_sal_int  varchar2(1); -- Tipo DÈbito/CrÈdito
  v_duplicado    varchar2(1) := 'N' ;
  v_cnt_mensaje  number;
  v_max_lineas   number := 999999;--28; -- Cantidad m·xima de lÌneas por mensaje.
  v_cnt_lineas   number := 0;
  v_secuencia    number := 0;
  v_cod_swift    varchar2(20);
  v_salto        varchar2(2) := CHR(13)||CHR(10);
  v_fecha        date;
  v_cod_swi_corresponsal varchar2(12);
  v_tipo         ge_transacciones.tipo%type; -- Tipo de Movimiento de la TransacciÛn, DÈbito/CrÈdito
  v_sal_inicial  ge_sal_diarios.sal_tot_cap%type;
  v_mto_intermedio  ge_sal_diarios.sal_tot_cap%type;
  v_mto_movimiento  ge_sal_diarios.sal_tot_cap%type;
  --Para cargar el statement number--
  v_nro_sec_cta  number;
  v_ind_sec_cta  varchar2(1);
  v_camp_61     varchar2(3) := 'MSC';
  v_tex_aux     varchar2(2000) := null;
  cursor c_cta is
     select c.nro_cuenta, c.cod_banco, c.cod_moneda, cc.cod_persona,
            nvl(c.sal_tot_batch,0) sal_tot_batch,
            nvl(c.sal_total,0) sal_total,
            nvl(c.sal_total,0) - nvl(c.sal_bloqueado,0) - nvl(c.sal_retenido,0) sal_disponible
       from cc_cta_corrientes c, ge_cta_clientes cc, ge_est_cuentas e
      where c.nro_cuenta = cc.nro_cuenta
        and cc.relacion = 'P'
        and c.cod_modulo = e.cod_modulo
        and c.cod_modalidad = e.cod_modalidad
        and c.estado = e.estado
        and e.activo = 'S'
        and c.cod_banco is not null
        and c.cod_banco = nvl(p_cod_banco,c.cod_banco)
        and c.nro_cuenta = nvl(p_nro_cuenta,c.nro_cuenta)
        and exists (select 1
                      from ge_cta_dat_adicionales da
                     where c.nro_cuenta = da.nro_cuenta
                       and da.parametro = 'MSJ_MT940_NEW'
                       and nvl(da.val_parametro,'N') = 'S')
     union all
     select v.nro_cuenta, v.cod_banco, v.cod_moneda, cc.cod_persona,
            nvl(v.sal_tot_batch,0) sal_tot_batch,
            nvl(v.sal_total,0) sal_total,
            nvl(v.sal_total,0) - nvl(v.sal_bloqueado,0) - nvl(v.sal_retenido,0) sal_disponible
       from ah_cta_vistas v, ge_cta_clientes cc, ge_est_cuentas e
      where v.nro_cuenta = cc.nro_cuenta
        and cc.relacion = 'P'
        and v.cod_modulo = e.cod_modulo
        and v.cod_modalidad = e.cod_modalidad
        and v.estado = e.estado
        and e.activo = 'S'
        and v.cod_banco is not null
        and v.cod_banco = nvl(p_cod_banco,v.cod_banco)
        and v.nro_cuenta = nvl(p_nro_cuenta,v.nro_cuenta)
        and exists (select 1
                      from ge_cta_dat_adicionales da
                     where v.nro_cuenta = da.nro_cuenta
                       and da.parametro = 'MSJ_MT940_NEW'
                       and nvl(da.val_parametro,'N') = 'S')
     order by 1;
  --
  c c_cta%rowtype;
  --
  cursor c_mov(p_cuenta varchar2) is
      select m.*
        from gv_movimientos m,
             ge_transacciones t
       where m.cod_modulo = t.cod_modulo
         and m.cod_modalidad = t.cod_modalidad
         and m.cod_transaccion = t.cod_transaccion
         and m.fecha = v_fecha
         and m.nro_cuenta = p_cuenta
         --- Para tomar reversiones
         and (m.reversado = 'N'
             or (m.reversado = 'S'
             and m.fec_valor < m.fecha
             and m.fec_valor <= v_fecha
             and m.monto < 0))
         --
         and nvl(m.monto,0) <> 0
         and upper(m.tip_movimiento) in ('DEBITO','CREDITO')
         and m.tipo = 'H'
         and t.ve_cliente = 'S'
       order by fecha, hora, nro_secuencia;
  --
  procedure lp_cab_mensaje is
  begin
    -- ********************Obtener y Actualizar el statemen number (Nro. de Extracto)******************
    if nvl(v_cnt_mensaje,1) = 1 then -- DYDMR-4562 -OMM-27/07/2016- Se agrega para no cambiar la secuencia por cantidad de msj
        v_nro_sec_cta := fug_obt_paradicional(c.nro_cuenta,'NRO_SEC_CTA_MT940');
        if v_nro_sec_cta is null then
           v_nro_sec_cta := 363;
           v_ind_sec_cta := 'N';
        else
            v_ind_sec_cta := 'S';
        end if;
        v_nro_sec_cta := v_nro_sec_cta + 1;
        if v_ind_sec_cta = 'S' then
            -- Actualiza la secuencia del Nro de Cuenta
            begin
              update ge_cta_dat_adicionales a
                 set a.val_parametro = trim(to_char(v_nro_sec_cta))
               where a.parametro = 'NRO_SEC_CTA_MT940'
                 and a.nro_cuenta = c.nro_cuenta;
              IF SQL%NOTFOUND THEN
                 raise_application_error(-20000,'Datos Adicionales no encontrado (Diario): '||sqlerrm);
              END IF;
            exception
              when others then
                  raise_application_error(-20001,'Error en Actualizacion de Datos Adicionales (Diario): '||sqlerrm);
            end;
        end if;
    end if ;
    -- ********************************** cabecera ****************************************************
    -- 1: DirecciÛn de Origen
    v_texto := null ;
    v_texto := v_texto||'{1:F01'||upper(v_cod_swift)||'XXX0000000000}';
    -- 2: DirecciÛn de Destino
    --Codigo BIC de 8 **Nuevo bloque IF
    if length(v_cod_swi_corresponsal) = 8 then
       v_texto := v_texto||'{2:I940'||upper(v_cod_swi_corresponsal)||'XXXXN'||'}';
    else
    --Codigo BIC de 11
       v_texto := v_texto||'{2:I940'||upper(substr(v_cod_swi_corresponsal,1,8))||'X'||upper(substr(v_cod_swi_corresponsal,-3))||'N'||'}';
    end if;

    v_texto := v_texto||'{4:'||v_salto;
    -- ****************************** cuerpo del mensaje **********************************************
    -- 20: Numero de referencia - IdentificaciÛn del Cliente y Fecha
    v_texto := v_texto||':20:C'||lpad(substr(trim(c.cod_persona),1,6),6,0)||lpad(v_secuencia,3,0)||v_fec_actual||v_salto;
    -- 21: Banco Emisor del Mensaje
    v_texto := v_texto||':21:'||upper(v_cod_swift)||v_fec_actual||v_salto;
    -- 25: Nro. de Cuenta Informada
    v_texto := v_texto||':25:'||c.nro_cuenta||v_salto;
    -- 28C: Nro. de Mensaje/Nro. de Secuencia
    select v_texto||':28C:'||lpad(to_char(v_nro_sec_cta),5,0)||'/'||lpad(v_cnt_mensaje,5,0)||v_salto
      into v_texto from dual;
    -- Tipo de Saldo CrÈdito o DÈbito
    if v_sal_inicial < 0 then
      v_tip_saldo := 'D';
    else
      v_tip_saldo := 'C';
    end if;
    -- 60F: Saldo dÌa Anterior
    if nvl(v_cnt_mensaje,1) = 1 then
       v_texto := v_texto||':60F:'||v_tip_saldo||v_fec_ant_chr||v_cod_moneda||replace(ltrim(rtrim(to_char(abs(v_sal_inicial),v_mascara))),'.',',')||v_salto;
    else -- OMM Ene/2018 se agrega el saldo intermedio cuando hay m·s de una pagina
        -- Tipo de Saldo CrÈdito o DÈbito
        if v_mto_intermedio < 0 then
          v_tip_sal_int := 'D';
        else
          v_tip_sal_int := 'C';
        end if;
       v_texto := v_texto||':60M:'||v_tip_sal_int||v_fec_actual||v_cod_moneda||replace(ltrim(rtrim(to_char(abs(v_mto_intermedio),v_mascara))),'.',',')||v_salto;
    end if ;

    if nvl(v_detalle,'N') = 'N' then
       if c.sal_disponible < 0 then
         v_tip_saldo := 'D';
       else
         v_tip_saldo := 'C';
       end if;
      -- 62F: Saldo Actual
      v_texto := v_texto||':62F:'||v_tip_saldo||v_fec_actual||v_cod_moneda||replace(ltrim(rtrim(to_char(abs(c.sal_disponible),v_mascara))),'.',',')||v_salto;
      -- 64: LÌnea de Operaciones
       v_texto := v_texto||':64:'||v_tip_saldo||v_fec_actual||v_cod_moneda||replace(ltrim(rtrim(to_char(abs(c.sal_disponible),v_mascara))),'.',',')||v_salto;
      v_texto := v_texto||'-}';
    else
      v_cnt_lineas := 5;
    end if;
  end;

  procedure lp_ini_sec_anual is
  begin
    if to_char(v_fecha,'yyyy') <> to_char(v_fec_anterior,'yyyy') then
       --Se debe reiniciar a 0 los parametros, cambio el aÒo--
       update ge_cta_dat_adicionales
          set val_parametro = '0'
        where parametro = 'NRO_SEC_CTA_MT940';
       IF SQL%NOTFOUND THEN
          raise_application_error(-20000,'Datos Adicionales no encontrado (Anual): '||sqlerrm);
       END IF;
    end if;
  exception
      when others then
          raise_application_error(-20001,'Error en Actualizacion de Datos Adicionales (Anual): '||sqlerrm);
  end;

  Procedure pr_ins_ge_men_cli_mt940 is
  Begin
      insert into ge_men_cli_mt940 (cod_persona, nro_cuenta, fec_extracto, nro_extracto,
                                    nro_secuencia,extracto, estado)
      values (c.cod_persona, c.nro_cuenta, v_fecha, v_nro_sec_cta,
              v_cnt_mensaje, v_texto, 'G') ;

  exception
  when others then
        raise_application_error(-20000,' Al insertar pr_ins_ge_men_cli_mt940: '||sqlerrm);
  end;
  
  --Funcion obtiene nombre de la Cuenta.
      FUNCTION lf_obt_nom_cuenta
   (
      p_nro_cuenta      ge_cuentas.nro_cuenta%type
   ) RETURN VARCHAR2  IS
      v_nom_cuenta     varchar2(2000) := 1;
   BEGIN       
    select denominacion
        into v_nom_cuenta
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;
        return v_nom_cuenta;
       Exception 
         when others then 
           return v_nom_cuenta;
    End; 
   --Funcion obtiene nro. documento.
      FUNCTION lf_obt_nro_documento
   (
      p_nro_cuenta      ge_cuentas.nro_cuenta%type
   ) RETURN VARCHAR2  IS
      v_nro_documento     varchar2(2000) := 1;
   BEGIN       
    select d.nro_documento
        into v_nro_documento
        from ge_cta_clientes a,ba_per_documentos d
       where a.nro_cuenta = p_nro_cuenta
         and a.relacion = 'P'
         and a.cod_persona = d.cod_persona;
        return v_nro_documento;
       Exception 
         when others then 
           return v_nro_documento;
    End; 
    
   --Funcion obtiene dir. persona.
      FUNCTION lf_obt_dir_persona
   (
      p_nro_cuenta      ge_cuentas.nro_cuenta%type
   ) RETURN VARCHAR2  IS
      v_dir_persona   varchar2(2000) := 1;
   BEGIN       
    select d.direccion
        into v_dir_persona
        from ge_cta_clientes a,ba_direcciones d
       where a.nro_cuenta = p_nro_cuenta
         and a.relacion = 'P'
         and a.cod_persona = d.cod_persona
         and d.principal = 'S'
         and rownum = 1;
        return v_dir_persona;
       Exception 
         when others then 
           return v_dir_persona;
    End; 
   --Funcion que obtiene el campo 86 para Trasnf via SNP.
   FUNCTION lf_obt_dat_86_snp
   (
      p_nro_documento ge_movimientos.nro_documento%type,
      p_concepto      ge_movimientos.concepto%type,
      p_tipo          ge_transacciones.tipo%type,
      p_cod_tra_padre ge_movimientos.cod_tra_padre%type  
   ) RETURN VARCHAR2  IS
      v_texto_86      varchar2(2000) := null;
   BEGIN
         Select ':86:/EREF/'||substr(ltrim(rtrim(upper(TRANSLATE(nvl(t.concepto,p_concepto), '·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞' || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ')))),1,56)||v_salto
        ||substr('/'||(decode(p_tipo,'C','BENM/NAME/1/','BENM/NAME/1/'))||substr(ltrim(rtrim(upper(TRANSLATE(decode(p_tipo,'C',t.nom_solicitante,t.nom_beneficiario), '·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞' || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        '))))
        ||'/2/'||decode(p_tipo,'C',t.nro_doc_solicitante,t.nro_doc_beneficiario),1,57),1,65)||v_salto
        ||substr('/3/'||decode(p_tipo,'C',nvl(t.dir_solicitante,'-'),nvl(t.dir_beneficiario,'-')),1,65)||v_salto
        ||substr('/TCODE/'||p_cod_tra_padre||'/REF/'||t.nro_referencia,1,65)||v_salto
        ||'/REMI/'||substr(t.observacion,1,60)||v_salto
      Into v_texto_86
      From ge_snp_transferencias t 
     Where t.nro_referencia = p_nro_documento;
      Return v_texto_86;
     Exception 
       When others then 
       Return v_texto_86;
   End;
   
   --Funcion que obtiene el campo 86 para Trasnf e/ Ctas. BBVA.
   FUNCTION lf_obt_dat_86_bbva
   (
      p_concepto      ge_movimientos.concepto%type,
      p_tipo          ge_transacciones.tipo%type,
      p_cod_tra_padre ge_movimientos.cod_tra_padre%type,
      p_nro_documento ge_movimientos.nro_documento%type 
   ) RETURN VARCHAR2  IS
      v_texto_86_bbva     varchar2(2000) := null;
      v_aux_1  number := 20;
      v_aux_2  number := 0; 
      v_aux_3  number := 0;  
      v_tex_aux_1 varchar2(2000) := null;
      v_tex_aux_2 varchar2(2000) := null;
      v_tex_aux_3 varchar2(2000) := null;
   BEGIN       
       if instr(p_concepto, 'TRANSF. TERCEROS A') > 0 THEN
         v_aux_2 := (instr(p_concepto,'DESDE',1,1)+6);
         v_aux_3 := (instr(p_concepto,'-',1,1)-1);
         v_tex_aux_2 := TRANSLATE(substr(p_concepto,(v_aux_3 + 2)),'·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞' || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ');
         if p_tipo = 'C' then
            v_tex_aux_1:= substr(p_concepto,v_aux_2,(v_aux_3 - v_aux_2));
                     v_tex_aux_3 := '/BENM/NAME/1/';          
         else
            v_tex_aux_1:= substr(p_concepto,v_aux_1,(v_aux_3 - v_aux_2)); 
            v_tex_aux_3 := '/BENM/NAME/1/';
         end if;   
            v_texto_86_bbva :=  ':86:/EREF/'||substr(ltrim(rtrim(upper(TRANSLATE(p_concepto, '·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞' || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ')))),1,56)||v_salto                                
                                ||substr(v_tex_aux_3||lf_obt_nom_cuenta(v_tex_aux_1)||'/2/'||lf_obt_nro_documento(v_tex_aux_1),1,65)||v_salto 
                                ||substr('/3/'||lf_obt_dir_persona(v_tex_aux_1),1,65)||v_salto 
                                ||substr('/TCODE/'||p_cod_tra_padre||'/REF/'||p_nro_documento,1,65)||v_salto;
       elsif instr(p_concepto, 'TRANSF. ENTRE CUENTAS A') > 0 THEN
             v_aux_3 := (instr(p_concepto,'-',1,1)-1);
             v_tex_aux_1:= substr(p_concepto,25,(v_aux_3 - 25)); 
             v_tex_aux_2 := TRANSLATE(substr(p_concepto,(v_aux_3 + 2)),'·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞' || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ');
             v_texto_86_bbva := ':86:/EREF/'||substr(ltrim(rtrim(upper(TRANSLATE(p_concepto, '·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞' || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ')))),1,56)||v_salto
                                ||substr('/BENM/NAME/1/'||lf_obt_nom_cuenta(v_tex_aux_1)||'/2/'||lf_obt_nro_documento(v_tex_aux_1),1,65)||v_salto 
                                ||substr('/TCODE/'||p_cod_tra_padre||'/REF/'||p_nro_documento,1,65)||v_salto;
       elsif instr(p_concepto, 'TRANSF. ENTRE CUENTAS DE') > 0 THEN
             v_aux_3 := (instr(p_concepto,'-',1,1)-1);
             v_tex_aux_1:= substr(p_concepto,26,(v_aux_3 - 26)); 
             v_tex_aux_2 := TRANSLATE(substr(p_concepto,(v_aux_3 + 2)),'·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞'|| CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ');
             v_texto_86_bbva := ':86:/EREF/'||substr(ltrim(rtrim(upper(TRANSLATE(p_concepto, '·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞'|| CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ')))),1,56)||v_salto
                                ||substr('/BENM/NAME/1/'||lf_obt_nom_cuenta(v_tex_aux_1)||'/2/'||lf_obt_nro_documento(v_tex_aux_1),1,65)||v_salto 
                                ||substr('/TCODE/'||p_cod_tra_padre||'/REF/'||p_nro_documento,1,65)||v_salto;
       else
           v_texto_86_bbva := ':86:/EREF/'||substr(ltrim(rtrim(upper(TRANSLATE(p_concepto, '·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞' || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ')))),1,56)||v_salto
                                ||substr('/TCODE/'||p_cod_tra_padre||'/REF/'||p_nro_documento,1,65)||v_salto;   
       end if; 
       return v_texto_86_bbva; 
   End;
   
   --Funcion que obtiene el campo 86 para Trasnf Internacional
   FUNCTION lf_obt_dat_86_int
   (
      p_nro_documento ge_movimientos.nro_documento%type,
      p_concepto      ge_movimientos.concepto%type,
      p_tipo          ge_transacciones.tipo%type,
      p_cod_tra_padre ge_movimientos.cod_tra_padre%type
   ) RETURN VARCHAR2  IS
      v_texto_86_int     varchar2(2000) := null;
   BEGIN       
       Select ':86:/EREF/'||substr(ltrim(rtrim(upper(TRANSLATE(p_concepto, '·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞' || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ')))),1,56)||v_salto
        ||substr('/'||(decode(p_tipo,'C','BENM/NAME/1/','BENM/NAME/1/'))||substr(ltrim(rtrim(upper(TRANSLATE(decode(p_tipo,'C',l.nom_solicitante,l.nom_beneficiario), '·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞'  || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        '))))
        ||'/2/'||decode(p_tipo,'C',1,l.nro_doc_beneficiario),1,57),1,65)||v_salto
        ||substr('/3/'||decode(p_tipo,'C',l.dir_solicitante,l.dir_beneficiario),1,65)||v_salto
        ||substr('/TCODE/'||p_cod_tra_padre||'/REF/'||l.nro_ref_externa,1,65)||v_salto
        ||substr('/REMI/'||l.observacion,1,65)||v_salto
       Into v_texto_86_int
      From lc_transferencias l 
     Where l.nro_operacion = p_nro_documento;
      Return v_texto_86_int;
     Exception 
       When others then 
       Return v_texto_86_int;
   END; 
   
      --Funcion que obtiene el campo 86 para Pago a Proveedores.
   FUNCTION lf_obt_dat_86_pag_pro
   (
      p_nro_documento ge_movimientos.nro_documento%type,
      p_concepto      ge_movimientos.concepto%type,
      p_tipo          ge_transacciones.tipo%type,
      p_cod_tra_padre ge_movimientos.cod_tra_padre%type,
      p_nro_doc3      ge_movimientos.nro_documento3%type
   ) RETURN VARCHAR2  IS
      v_texto_86_pag_pro     varchar2(2000) := null;
      v_nro_cta_cre          ge_pag_proveedores.nro_cta_credito%type := null;  
      v_concepto             ge_pag_proveedores.concepto%type := null;
      v_beneficiario         ge_pag_proveedores.beneficiario%type := null;
      v_nro_doc_ben          ge_pag_proveedores.nro_doc_beneficiario%type := null;
      v_dir_ben              ge_pag_proveedores.dir_beneficiario%type := null;
      v_observacion          ge_pag_proveedores.ref_facturas%type := null;
   BEGIN         
       Select r.nro_cta_credito,r.concepto,r.beneficiario,r.nro_doc_beneficiario,
              r.dir_beneficiario,r.ref_facturas
       Into v_nro_cta_cre,v_concepto,v_beneficiario,v_nro_doc_ben,v_dir_ben,v_observacion
      From ge_pag_proveedores r 
     Where r.nro_documento = p_nro_documento
       and r.cod_ente = p_nro_doc3;
      If v_nro_doc_ben is null then 
        v_nro_doc_ben:= lf_obt_nro_documento(v_nro_cta_cre);
      End If;
      If v_dir_ben is null then 
        v_dir_ben := lf_obt_dir_persona(v_nro_cta_cre);
      End If;
      v_texto_86_pag_pro :=':86:/EREF/'||substr(ltrim(rtrim(upper(TRANSLATE(v_concepto, '·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞' || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ')))),1,56)||v_salto
        ||substr('/BENM/NAME/1/'||v_beneficiario||'/2/'||v_nro_doc_ben,1,65)||v_salto 
        ||substr('/3/'||v_dir_ben,1,65)||v_salto
        ||substr('/TCODE/'||p_cod_tra_padre||'/REF/'||p_nro_documento,1,65)||v_salto
        ||substr('/REMI/'||v_observacion,1,65)||v_salto;
      Return v_texto_86_pag_pro;
     Exception 
       When others then 
       Return v_texto_86_pag_pro;
   END;   
BEGIN

  if p_fecha is null then
     v_fec_actual := to_char(pae_cnf.fu_obt_fec_actual(4),'yymmdd');
     v_fecha := trunc(pae_cnf.fu_obt_fec_actual(4));
  else
      v_fec_actual := to_char(p_fecha,'yymmdd');
      v_fecha := trunc(p_fecha);
  end if ;
  -- Valida que solo se ejecute una vez por dÌa
  Begin
     Select 'S' into v_duplicado
     from ge_men_cli_mt940 a
     where a.fec_extracto = v_fecha ;
  exception
  when no_data_found then
        v_duplicado := 'N';
  when others then
        v_duplicado := 'N';
  end;
  -- Control para no generar duplicados
  if v_duplicado = 'S' then
     raise_application_error(-20000,'Ya se encuentran registros de la fecha: '||v_fecha) ;
  end if ;

  lp_ini_sec_anual;
  -- defino el nombre del archivo
  --v_nom_archivo := 'PYXTR'||v_fec_actual||to_char(p_fecha, 'hh24miss')||'.IXT';
  -- obtengo el codigo de swift del banco origen
  select substr(upper(cod_swift),1,9) into v_cod_swift from ge_bancos where cod_banco = fug_obt_cod_banco;
  -- leo los datos del registro de la operacion
  --
  if c_cta%isopen then
    close c_cta;
  end if;
  --
  open c_cta;
  --
  loop
    fetch c_cta into c;
    --
    exit when c_cta%notfound;
    -- Cantidad de Mensajes
    v_cnt_mensaje := 1;
    -- Cantidad de Cuentas
    v_secuencia := v_secuencia + 1;
    v_mto_movimiento := 0;
    v_mto_intermedio := 0;
    v_texto := '' ;
    --
    if c.cod_moneda = 'GS' then
      v_cod_moneda := 'PYG';
      v_mascara := '999999999990D';--999999999999
    else
      v_cod_moneda := c.cod_moneda;
      v_mascara := '999999999990D99';
    end if;
    -- obtengo los datos del banco corresponsal del operante
    begin
      select upper(trim(a.cod_swift)) --substr(upper(a.cod_swift),1,9) Comentado xq se controla el length en la linea 85
        into v_cod_swi_corresponsal
        from ge_bancos a
       where a.cod_banco = c.cod_banco;
    exception
       when others then
           v_cod_swi_corresponsal := null;
    end;
    -- Busca si la cta. tiene movimientos
    begin
      select distinct 'S'
        into v_detalle
        from gv_movimientos m,
             ge_transacciones t
       where m.cod_modulo = t.cod_modulo
         and m.cod_modalidad = t.cod_modalidad
         and m.cod_transaccion = t.cod_transaccion
         and m.fecha = v_fecha
         and m.nro_cuenta = c.nro_cuenta
         --- Para tomar reversiones
         and (m.reversado = 'N'
             or (m.reversado = 'S'
             and m.fec_valor < m.fecha
             and m.fec_valor <= v_fecha
             and m.monto < 0))
         --
         and nvl(m.monto,0) <> 0
         and upper(m.tip_movimiento) in ('DEBITO','CREDITO')
         and m.tipo = 'H'
         and t.ve_cliente = 'S';
    exception
      when no_data_found then
        v_detalle := 'N';
      when others then
        raise_application_error(-20012,'Movimientos. '||sqlerrm);
    end;
    -- OMM ENE/2018 ESTO SE AGREGAR¡ EN LA GENERACI”N DEL ARCHIVO COMO SEPARADOR
/*    if v_secuencia > 1 then
      -- Existe otra Cta. en el mismo Archivo se debe colocar $.
      v_texto := v_texto||'$';
    end if;*/
    -- Busca Saldo Inicial de la Cuenta
    begin
      select (s.sal_tot_cap -s.sal_blo_int-s.sal_ret_ade)-- s.sal_tot_cap
        into v_sal_inicial
        from ge_sal_diarios s
       where nro_cuenta = c.nro_cuenta
         and fecha = v_fec_anterior;
    exception
      when no_data_found then
        v_sal_inicial := 0;
      when others then
        raise_application_error(-2013,'Error al buscar el Saldo Inicial. '||sqlerrm);
    end;
    v_mto_intermedio := v_sal_inicial ; -- Se inicia con el monto inicial
    -- Genera la Cabecera del Mensaje MT940
    lp_cab_mensaje;
    -- Si la cta tiene movimientos genera los detalles.
    if v_detalle = 'S' then
      for m in c_mov(c.nro_cuenta) loop
        -- Si la cantidad de lÌneas supera la Maxima, inserta otro Mensaje.
        if v_cnt_lineas = v_max_lineas  or nvl(length(v_texto),1) > 1600 then
          -- Tipo de Saldo CrÈdito o DÈbito
          if c.sal_disponible < 0 then
            v_tip_saldo := 'D';
          else
            v_tip_saldo := 'C';
          end if;

          v_mto_intermedio := v_mto_intermedio + v_mto_movimiento ;
          v_mto_movimiento := 0;
           -- Tipo de Saldo CrÈdito o DÈbito
          if v_mto_intermedio < 0 then
            v_tip_sal_int := 'D';
          else
            v_tip_sal_int := 'C';
          end if;
          -- 62M: Saldo Saldo Intermedio
          v_texto := v_texto||':62M:'||v_tip_sal_int||v_fec_actual||v_cod_moneda||replace(ltrim(rtrim(to_char(ABS(v_mto_intermedio),v_mascara))),'.',',')||v_salto;

          -- 64: LÌnea de Operaciones
          v_texto := v_texto||':64:'||v_tip_saldo||v_fec_actual||v_cod_moneda||replace(ltrim(rtrim(to_char(ABS(c.sal_disponible),v_mascara))),'.',',')||v_salto;
          -- Fin del Mensaje con Movimientos.
          v_texto := v_texto||'-}$';
          pr_ins_ge_men_cli_mt940 ;
          v_texto := '' ;
          -- Cantidad de Mensajes
          v_cnt_mensaje := v_cnt_mensaje + 1;
          -- Aumenta la secuencia
          v_secuencia := v_secuencia + 1;
          -- Genera la Cabecera del Mensaje MT940
          lp_cab_mensaje;
        end if;
        -- armo las partes del cuerpo del mensaje
        -- Tipo de movimiento Debito o Credito
        v_tipo := m.cod_tip_movimiento;
        -- OMM ENE/2018 Para tener en cuenta reversiones de ATM (no marca como reversado los movimientos
        if m.monto < 0 then
           if v_tipo = 'C' then
              v_tipo := 'D' ;
           else
              v_tipo := 'C' ;
           end if;
        end if ;
        --Obtener el codigo Swift seg˙n transaccion.
         v_camp_61 := NVL(fug_obt_par_transacciones(m.cod_tra_padre,m.cod_mod_padre,m.cod_mad_padre,'COD_TRA_SWIFT_MT940'),'MSC');
        -- 61: Saldo LÌnea de OperaciÛn
          v_texto := v_texto||':61:'||v_fec_actual||substr(v_fec_actual,3,6)||v_tipo||substr(v_cod_moneda,3,1)
                            ||replace(ltrim(rtrim(to_char(ABS(m.monto),v_mascara))),'.',',')||'N'||v_camp_61
                            ||'NONREF//'||nvl(m.nro_documento, m.nro_documento4)||v_salto;
          v_tex_aux := m.cod_tra_padre||m.cod_mod_padre||m.cod_mad_padre||' '||upper(TRANSLATE(m.des_tra_padre, '·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞' || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        '));
          v_texto := v_texto||substr(v_tex_aux,1,34)||v_salto;
          v_tex_aux := null;
        --Etiqueta 86:          
        if FUP_EXI_GRU_TRANSAC(202,m.cod_tra_padre,m.cod_mod_padre, m.cod_mad_padre) = 'S' then --Si es Tranferencia via SNP
            v_texto := v_texto||lf_obt_dat_86_snp(m.nro_documento,m.concepto,v_tipo,(m.cod_tra_padre||m.cod_mod_padre||m.cod_mad_padre));
        elsif FUP_EXI_GRU_TRANSAC(203,m.cod_tra_padre,m.cod_mod_padre, m.cod_mad_padre) = 'S' then --Si es Tranferencia entre ctas BBVA     
              v_texto := v_texto||lf_obt_dat_86_bbva(upper(m.concepto),v_tipo,(m.cod_tra_padre||m.cod_mod_padre||m.cod_mad_padre),m.nro_documento);    
        elsif FUP_EXI_GRU_TRANSAC(204,m.cod_tra_padre,m.cod_mod_padre, m.cod_mad_padre) = 'S' then --Si es Tranferencia Internacional     
              v_texto := v_texto||lf_obt_dat_86_int(m.nro_documento,m.concepto,v_tipo,(m.cod_tra_padre||m.cod_mod_padre||m.cod_mad_padre));            
        elsif FUP_EXI_GRU_TRANSAC(205,m.cod_tra_padre,m.cod_mod_padre, m.cod_mad_padre) = 'S' then --Pago a Proveedores BBVA    
              v_texto := v_texto||lf_obt_dat_86_pag_pro(m.nro_documento,m.concepto,v_tipo,(m.cod_tra_padre||m.cod_mod_padre||m.cod_mad_padre),m.nro_documento3);                    
        else
              v_texto := v_texto||':86:/EREF/'||substr(ltrim(rtrim(upper(TRANSLATE(nvl(m.concepto,m.des_transaccion), '·ÈÌÛ˙‡ËÏÚ˘„ı‚ÍÓÙÙ‰ÎÔˆ¸ÁÒ¡…Õ”⁄¿»Ã“Ÿ√’¬ Œ‘€ƒÀœ÷‹«—@<>_#-∞' || CHR(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ')))),1,56)||v_salto
                                ||substr('/TCODE/'||(m.cod_tra_padre||m.cod_mod_padre||m.cod_mad_padre)||'/REF/'||m.nro_documento,1,65)||v_salto; 
        end if; 
          v_cnt_lineas := v_cnt_lineas + 1;
        if m.cod_tip_movimiento = 'C' then
           v_mto_movimiento := v_mto_movimiento + m.monto ;
        else
           v_mto_movimiento := v_mto_movimiento - m.monto ;
        end if ;
      end loop;

      if c.sal_disponible < 0 then
        v_tip_saldo := 'D';
      else
        v_tip_saldo := 'C';
      end if;

      v_texto := v_texto||':62F:'||v_tip_saldo||v_fec_actual||v_cod_moneda||replace(ltrim(rtrim(to_char(abs(c.sal_disponible),v_mascara))),'.',',')||v_salto;
      -- 64: LÌnea de Operaciones
      v_texto := v_texto||':64:'||v_tip_saldo||v_fec_actual||v_cod_moneda||replace(ltrim(rtrim(to_char(abs(c.sal_disponible),v_mascara))),'.',',')||v_salto;

      -- Fin del Mensaje con Movimientos.
      v_texto := v_texto||'-}';
      pr_ins_ge_men_cli_mt940 ;
    else
       pr_ins_ge_men_cli_mt940 ;
    end if;
  end loop;

  Begin
    Delete ge_men_cli_mt940 b
    where b.fec_extracto < trunc(sysdate) - 30 ;
  exception
     when others then
        -- no debe tener error
        null ;
  end;

exception
   when others then
       raise_application_error(-2000,'Error en PRG_GEN_MSJ_MT940: '||sqlerrm);
END;
/

