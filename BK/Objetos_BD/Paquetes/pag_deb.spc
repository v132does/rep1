CREATE OR REPLACE PACKAGE IT.pag_deb IS
   -- Author  : XPY0038
   -- Created : 16/02/2015 08:28:28 a.m.
   -- Purpose : Cargo Seguro de Tarjetas de Débito.
   -- Public function and procedure declarations
   FUNCTION fu_obt_ente RETURN VARCHAR2;
   PROCEDURE pr_ins_seg_fra;
   PROCEDURE pr_deb_seg_fra(p_nro_cta_debito ge_cuentas.nro_cuenta%TYPE DEFAULT NULL,
                            p_mes_cuota      ge_seg_fraude_det.mes%TYPE DEFAULT NULL,
                            p_hora           IN OUT ge_movimientos.hora%TYPE,
                            p_nro_secuencia  IN OUT ge_movimientos.nro_secuencia%TYPE,
                            p_tip_proceso    varchar2 DEFAULT 'C');
   PROCEDURE pr_gen_ganancia(p_nro_cta_debito IN ge_cuentas.nro_cuenta%TYPE DEFAULT NULL,
                             p_hora           IN OUT ge_movimientos.hora%TYPE,
                             p_nro_secuencia  IN OUT ge_movimientos.nro_secuencia%TYPE,
                             p_es_nocturno    IN VARCHAR2 DEFAULT 'N');
   PROCEDURE pr_deb_pag_sue;
   PROCEDURE pr_del_seg_fra;
   PROCEDURE pr_pro_seg_fra;
END pag_deb;
/

