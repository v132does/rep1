CREATE OR REPLACE PROCEDURE IT.pra_gen_cta_vista(p_cod_persona ba_personas.cod_persona%TYPE,
                                              p_cod_oficina ba_oficinas.cod_oficina%TYPE,
                                              p_cod_moneda ba_monedas.cod_moneda%TYPE
                                              DEFAULT pag_gen.fu_obt_mon_local,
                                              p_cod_canal ah_cta_vistas.cod_canal%type,
                                              p_cod_campana ah_cta_vistas.cod_campana%type,
                                              p_nro_cuenta OUT cc_cta_corrientes.nro_cuenta%TYPE ) IS
  v_cuenta       ge_cuentas.nro_cuenta%type;
  v_denominacion cc_cta_corrientes.denominacion%type;
  --v_nom_chequera cc_cta_corrientes.nom_chequera%type;
  v_pri_nombre   ba_per_fisicas.pri_nombre%type;
  v_seg_nombre   ba_per_fisicas.seg_nombre%type;
  v_pri_apellido ba_per_fisicas.pri_apellido%type;
  v_seg_apellido ba_per_fisicas.seg_apellido%type;
  v_fec_apertura date default pag_cal.fu_obt_fec_actual(3);
  v_anio         varchar2(10);
  v_embozado     ah_tar_debitos.embozado%type;
  v_fec_vencimiento ah_tar_debitos.fec_vencimiento%type;
  v_cod_pro_bancard VARCHAR2(10) := fug_obt_pardinamico('COD_PRO_BANCARD', NULL, NULL, NULL, NULL);
  v_nro_bin_procesadora ah_tar_debitos.nro_bin%TYPE := fug_obt_parentes(v_cod_pro_bancard, 'NRO_BIN_TAR_DEBITO');
  v_cod_tasa     ah_cta_vistas.cod_tasa%type;
  v_est_modulo   ba_modulos.estado%type;
  
  --v_fec_apertura date;
  FUNCTION lf_obt_nombre
   (
      p_pri_nombre   VARCHAR2,
      p_seg_nombre   VARCHAR2,
      p_pri_apellido VARCHAR2,
      p_seg_apellido VARCHAR2,
      p_tamano       NUMBER
   ) RETURN VARCHAR2 IS
      v_nombre VARCHAR2(120);
   BEGIN

      IF length(p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
         IF length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
            IF length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
               v_nombre := p_pri_nombre||' '||p_pri_apellido;
            ELSE
               v_nombre := TRIM(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
            END IF;
         ELSE
            v_nombre := TRIM(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
         END IF;
      ELSE
         v_nombre := TRIM(p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
      END IF;

      RETURN v_nombre;
   END;
BEGIN
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End;
  v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);
  if fug_obt_pardinamico('ACT_CTA_PRESTAMOS') = 'S' then
    BEGIN
      SELECT a.pri_nombre, a.seg_nombre,
             a.pri_apellido, a.seg_apellido
        INTO v_pri_nombre, v_seg_nombre,
             v_pri_apellido, v_seg_apellido
        FROM ba_per_fisicas a
       WHERE a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        raise_application_error(-20000,'Error en PRC_GEN_CTA_CORRIENTES Persona '||p_cod_persona||' Inexistente, o no es Persona FМsica.');
    END;
    v_denominacion := lf_obt_nombre(v_pri_nombre, v_seg_nombre,v_pri_apellido, v_seg_apellido,65);
    --v_nom_chequera := lf_obt_nombre(v_pri_nombre, v_seg_nombre,v_pri_apellido, v_seg_apellido,60);
    v_cuenta := fug_obt_sig_nro_cuenta(3,31,p_cod_oficina,p_cod_moneda,p_cod_persona);
    
    if p_cod_moneda = 'GS' then
       v_cod_tasa := 899;
    elsif p_cod_moneda = 'USD' then
       v_cod_tasa := 583;
    elsif p_cod_moneda = 'EUR' then
       v_cod_tasa := 899;
    end if;
    
    BEGIN
      INSERT INTO ah_cta_vistas
        (NRO_CUENTA, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, DENOMINACION, FRE_EXTRACTO, 
         FEC_APERTURA, FEC_ULT_MOVIMIENTO, TIP_CAPITALIZACION, TAS_PERSONALIZADA, COD_TASA, 
         RET_PERSONALIZADA, EST_BATCH, ESTADO, REG_FIRMA, COD_SUB_MODALIDAD, COD_CANAL, COD_CAMPANA)
      VALUES
        (v_cuenta, 3, 31, p_cod_oficina, p_cod_moneda, v_denominacion, 'M', 
         v_fec_apertura, v_fec_apertura, 1, 'N', v_cod_tasa, 
         'N', 'A', 'A', 'ALTA AUTOMATICA PARA PRESTAMO', 1, p_cod_canal, p_cod_campana);
    EXCEPTION
       WHEN OTHERS THEN
          raise_application_error(-20001, 'Error al insertar datos en AH_CTA_VISTAS. Persona = '||p_cod_persona||' '||SQLERRM);
    END;
    --11/2020 para insertar en tabla nocturna
    --Si esta en cerrado o en proceso de cierre 
    if nvl(v_est_modulo,99) in (4,3) then
      BEGIN
        INSERT INTO ah_cta_vistas_noc
          (NRO_CUENTA, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, DENOMINACION, FRE_EXTRACTO, 
           FEC_APERTURA, FEC_ULT_MOVIMIENTO, TIP_CAPITALIZACION, TAS_PERSONALIZADA, COD_TASA, 
           RET_PERSONALIZADA, EST_BATCH, ESTADO, REG_FIRMA, COD_SUB_MODALIDAD, COD_CANAL, COD_CAMPANA)
        VALUES
          (v_cuenta, 3, 31, p_cod_oficina, p_cod_moneda, v_denominacion, 'M', 
           v_fec_apertura, v_fec_apertura, 1, 'N', v_cod_tasa, 
           'N', 'A', 'A', 'ALTA AUTOMATICA PARA PRESTAMO', 1, p_cod_canal, p_cod_campana);
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20001, 'Error al insertar datos en AH_CTA_VISTAS_NOC. Persona = '||p_cod_persona||' '||SQLERRM);
      END;
    
      
    end if;
    
    
    
    v_embozado := lf_obt_nombre(v_pri_nombre, v_seg_nombre, v_pri_apellido, v_seg_apellido, 25);
    v_embozado := translate(v_embozado, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890яаимсз.+╢~-|╟╛!"#$%&/()=?║©*╗{}^`[]_:;,><гц',
                                                  'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890NAEIOU. ');
   /* BEGIN-- SE COMENTA LA GENERACION DE SOLICITUD DE TDD X ERROR - DYDMR-11224 - 11/07/2019
       --v_lugar           := '29-VEN_TAR_DEBITOS';
       v_anio            := fug_obt_pardinamico('VEN_TAR_DEBITOS');
       v_fec_vencimiento := last_day(add_months(v_fec_apertura, (nvl(v_anio, 3) * 12)));

       INSERT INTO ah_tar_debitos
          (nro_cuenta, tar_activa, fec_ingreso, cod_persona, embozado, cod_usuario,
           fec_grabacion, nro_emision, cod_ofi_origen, fec_vencimiento, tip_envio,
           referencia, cod_est_solicitud, cod_ent_procesadora, tip_tar_debito, nro_bin, renovacion)
       VALUES
          (v_cuenta, 'N', v_fec_apertura, p_cod_persona, v_embozado, USER,
           SYSDATE, '01', p_cod_oficina, v_fec_vencimiento, 'D',
           1, 3, v_cod_pro_bancard, 'N', v_nro_bin_procesadora, 'N');

    EXCEPTION
       WHEN OTHERS THEN
          raise_application_error(-20002, 'Error al insertar en AH_TAR_DEBITOS. '||SQLERRM);
    END;*/
    --
    BEGIN
      INSERT INTO ge_cta_clientes
           (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo, cod_modalidad, relacion)
      VALUES
           (p_cod_persona, v_cuenta, 0, p_cod_oficina, 3,31, 'P');

      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20004, 'Error al insertar datos en GE_CTA_CLIENTES. Persona: '
          ||p_cod_persona||' Cuenta: '||v_cuenta||SQLERRM);
      END;

     p_nro_cuenta := v_cuenta;
   end if;
END;
/

