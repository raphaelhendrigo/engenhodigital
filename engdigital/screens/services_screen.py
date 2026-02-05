"""Services screen for Engenho Digital app."""

from kivy.properties import ListProperty, StringProperty
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.screenmanager import Screen


class ServicesScreen(Screen):
    """Simple list of offered services."""

    services = ListProperty(
        [
            {
                "title": "Desenvolvimento de Software",
                "description": "Aplicações web modernas em Flask, React, APIs e bancos relacionais/NoSQL.",
            },
            {
                "title": "Projetos Elétricos CAD/CAM",
                "description": "Diagramas, layouts, quadros e listas de materiais prontos para execução.",
            },
            {
                "title": "Automação e Dados",
                "description": "ETL/ELT, relatórios automatizados e pipelines para aliviar trabalho manual.",
            },
        ]
    )

    overview = ListProperty(
        [
            {
                "index": "1",
                "title": "Software sob medida",
                "description": "Sistemas web em Flask, React e cloud, focados em automação, dashboards e integrações.",
            },
            {
                "index": "2",
                "title": "Projetos elétricos em CAD/CAM",
                "description": "Plantas, diagramas, quadros e detalhamento técnico para obras e indústrias.",
            },
            {
                "index": "3",
                "title": "Consultoria em dados e automação",
                "description": "Dados para reduzir retrabalho, padronizar processos e ganhar previsibilidade.",
            },
        ]
    )

    detailed_services = ListProperty(
        [
            {
                "title": "Desenvolvimento de Software",
                "summary": "Aplicações web modernas usando Flask, React, APIs em Python e bancos relacionais e NoSQL.",
                "bullets": [
                    "Sistemas internos e portais web",
                    "Dashboards para indicadores de gestão",
                    "Integração com serviços em nuvem e APIs",
                ],
            },
            {
                "title": "Projetos Elétricos CAD/CAM",
                "summary": "Projetos em AutoCAD e ferramentas CAM para instalações elétricas prediais, industriais e de infraestrutura.",
                "bullets": [
                    "Diagramas unifilares e trifilares",
                    "Layouts de iluminação e tomadas",
                    "Quadros de cargas, listas de materiais e detalhamento",
                ],
            },
            {
                "title": "Automação & Dados",
                "summary": "Modelagem de dados, automação de relatórios e criação de pipelines que aliviam o trabalho manual do dia a dia.",
                "bullets": [
                    "Rotinas de ETL/ELT para planilhas e bancos",
                    "Automatização de relatórios técnicos e laudos",
                    "Suporte para uso de inteligência artificial aplicada ao negócio",
                ],
            },
        ]
    )


class ServiceCard(BoxLayout):
    """Card-like container for displaying a service."""

    title = StringProperty("")
    description = StringProperty("")


class DetailedServiceCard(BoxLayout):
    """Card with summary and bullets."""

    title = StringProperty("")
    summary = StringProperty("")
    bullet1 = StringProperty("")
    bullet2 = StringProperty("")
    bullet3 = StringProperty("")
